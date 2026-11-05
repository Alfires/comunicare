# GUI tablet specification

## Status and authority

**Specified — 2026-11-05. Nothing here is implemented yet.** This document
settles every open decision in the
[GUI theme, usability and avatar preview roadmap](gui-theme-and-avatar-preview-roadmap.md).
The roadmap says *what* to build. This document fixes values, layouts, texts and
behavior. The [acceptance tests](../../tests/gui_tablet/README.md) check the
rules here.

Change a value only with evidence, such as a headset readability test or a
contrast failure. Update this document and the matching test in the same
commit. Values marked *(tunable)* may change after manual testing without a
test change.

## 1. Decisions

| # | Question | Decision |
| --- | --- | --- |
| D1 | Which Quick tiles? | Six tiles: **Mute**, **Emotes**, **Change avatar**, **Invite**, **Respawn**, **Mirror**. Removed: *Hide avatars* (there is no global hide; per-player Hide stays on the Instance page), *Camera* (no camera feature exists) and *Go home* (no defined target; Respawn covers "get me unstuck"). |
| D2 | Where do the home menu's profile button and friend presence go? | The status bar, on the left: `%ProfileButton` (own profile picture) and `%PresenceButton` (Online / Do not disturb / Appear offline). |
| D3 | VR text is too small at 1600 px over 0.55 m | The VR SubViewport renders 1600 × 1200 physical pixels but lays out at **1000 × 750 logical pixels** (`size_2d_override`, stretch on, 1.6×). 18 px body text is then about 1° of visual angle at arm's length. |
| D4 | Font | **Atkinson Hyperlegible Next** (Braille Institute, SIL OFL 1.1), Regular and SemiBold only. It was designed for legibility, which also suits VR panels. |
| D5 | What replaces `home_menue.tscn`? | `quick_page.tscn`. `home_menue.tscn/.gd` are deleted in Part 6; the tests that load it move to the Quick page or the shell in the same commit (see §9). |
| D6 | Can the player move while the PC menu is open? | No change: movement and looking stay blocked while the mouse is visible, as today (`player_desktop_movment.gd`). |
| D7 | Is tablet placement saved? | Session only. It is kept in memory by `player_vr.gd`; nothing is written to disk. |
| D8 | Pinned tablet plus walking or teleport | While open and pinned, the tablet stays in the world. On reopen it is restored relative to the player (yaw and position). Summon brings it back at any time. |
| D9 | Summon gesture | **Hold** the main menu button ≥ 0.6 s: opens if closed and moves the tablet in front. A short press toggles open/closed as today. No double press is used, so a first press never closes the tablet by accident. |
| D10 | Meaning of `vr.menu_hand` | Which side the tablet opens on: *Left* / *Right* place it 0.12 m toward that hand; *Centered* (`either`, default) places it straight ahead. |
| D11 | Where do toasts appear? | One `ToastHost` per shell (desktop overlay and VR tablet). Pages call `ToastHost.find_for(self).show_message(...)`. |
| D12 | Which dialogs stay modal? | Only confirmations of destructive or irreversible actions (`ConfirmationDialog`) and the existing account/key recovery errors (`error_popup.gd`). Everything informational becomes a toast or inline text. |
| D13 | Does clicking outside the PC menu close it? | Yes. A click on `%Dim` closes the menu, unless a key binding is being recorded. |
| D14 | What does *Match 3D highlight* map to? | cyan → Teal, yellow → Amber, green → Green, magenta → Rose, white → Neutral (§2.2). |

## 2. Visual tokens

### 2.1 Presets

Hex values are sRGB. All pass the test rules: text ≥ 4.5:1 (≥ 7:1 for High
contrast), surfaces with HSV saturation ≤ 0.25. They were checked with an
independent WCAG script: body text is 12–21:1 and muted text about 6.4:1.

| Token | Graphite | Paper | Forest | Sand | Night | High contrast |
| --- | --- | --- | --- | --- | --- | --- |
| kind | dark | light | dark | light | dark | hc |
| background | `#1c1d1f` | `#f3f1ec` | `#1a201d` | `#efe8dc` | `#0b0b0c` | `#000000` |
| surface | `#242528` | `#fbfaf7` | `#212824` | `#f7f2e9` | `#131315` | `#000000` |
| surface_raised | `#2e3034` | `#ffffff` | `#2a322d` | `#fdfaf4` | `#1b1b1e` | `#141414` |
| border | `#4a4d52` | `#cfccc4` | `#45504a` | `#d3c8b5` | `#34343a` | `#ffffff` |
| text | `#ebe9e4` | `#1f2023` | `#e6ebe7` | `#2b261f` | `#d9d8d4` | `#ffffff` |
| text_muted | `#a9a7a1` | `#5a5c61` | `#a3ada6` | `#5e564a` | `#9a9893` | `#e6e6e6` |
| preview_stage | `#2b2c2f` | `#e6e3dc` | `#28302b` | `#e4dccd` | `#18181b` | `#1a1a1a` |
| overlay_dim | black 55 % | `#1a1a1a` 45 % | black 55 % | `#1a1a1a` 45 % | black 65 % | black 75 % |

Semantic colors depend on the preset kind:

| kind | success | warning | danger |
| --- | --- | --- | --- |
| dark | `#6fbf73` | `#e0b040` | `#e5675c` |
| light | `#2e7d32` | `#8a6100` | `#b3261e` |
| hc | `#5ee08a` | `#ffd23f` | `#ff6b5e` |

### 2.2 Accents

| Accent | on dark | on light | on high contrast |
| --- | --- | --- | --- |
| Teal (default) | `#4fb3a9` | `#1d6b64` | `#6fd6cb` |
| Blue | `#6ea1e0` | `#2b5ea8` | `#8fb8ee` |
| Amber | `#e0a43a` | `#85591c` | `#f0bd5e` |
| Green | `#7bbf6a` | `#3a6b2c` | `#98d488` |
| Rose | `#e07a8f` | `#a3364d` | `#eda0b0` |
| Violet | `#a58be0` | `#6747a6` | `#c0aeee` |
| Neutral (white highlight only) | `#d6d3cc` | `#3a3c40` | `#e6e6e6` |

- `accent_text` is `#121314` on dark and high-contrast accents, and `#ffffff` on light accents.
- `focus` is the accent, except on High contrast, where it is `#ffff00`.

### 2.3 Typography

| Style | Size | Weight | Color |
| --- | --- | --- | --- |
| Body (`Label`, `Button`, inputs) | 18 px | Regular | text |
| `HeaderLabel` (page titles) | 24 px | SemiBold | text |
| `CaptionLabel` (captions, clock, nav labels) | 14 px | Regular | text_muted |
| `MutedLabel` (secondary body) | 18 px | Regular | text_muted |
| `PrimaryButton` | 18 px | SemiBold | accent_text |

Line spacing is the font default. No italics and no all-caps.

### 2.4 Geometry

- **Spacing scale:** 4, 8, 12, 16, 24, 32 px.
  - Box containers: separation 8.
  - GridContainer: 12 horizontal and vertical.
  - Page padding: 24, or 16 in compact mode.
- **Radii:**
  - 4 px for buttons, inputs and list rows.
  - 6 px for panels and popups.
  - 12 px for the tablet frame, which is the device outline and the only exception.
- **Borders:** 1 px `border` on inputs, panels and cards. Buttons have no border, except High contrast, which uses a 1 px `border`.
- **Focus:** 2 px `focus` ring, `expand_margin` 2, no fill.
- **Shadows** are allowed only on:
  - `TabletFrame` (8 px, 30 % alpha on dark / 18 % on light, offset 0,2)
  - `Toast` (6 px, 25 %)
  - popups (8 px, 30 %)
- **Never used:** gradients, glow, blur, textured styleboxes.

### 2.5 Control states

| State | Dark presets | Light presets |
| --- | --- | --- |
| hover | surface_raised mixed 8 % toward text | surface_raised mixed 5 % toward text |
| pressed / active | mixed 14 % toward text | mixed 10 % toward text |
| disabled | text at 45 % alpha, background unchanged | same |
| PrimaryButton hover | accent lightened 8 % | accent darkened 8 % |

`NavButton` active: `surface_raised` fill with a 3 px left border in `accent`.
Toggle tiles that are switched on (Mute when muted, Mirror when shown) use the
same active style.

### 2.6 Icons

- 24 × 24 viewBox, 1.75 px stroke, round caps and joins, no fill, white
  stroke (`#ffffff`); Godot tints them with the theme's icon colors.
- Shown at 24 px in buttons and 32 px on Quick tiles.
- Required set: home, quick, friends, world, avatar, instance, settings, emote,
  close, search, rotate, zoom, reset, folder, warning, check, people, pin, plus
  the existing microphone, microphone_muted, profile, back, edit.
- Own drawings or a CC0/OFL/MIT icon set recorded in `THIRD_PARTY_ASSETS.md`.
  Never emoji and never Unicode arrows as icons.

## 3. Layout

Sizes are **logical pixels** at `interface.ui_scale` 1.0.

### 3.1 Shell

```
┌ StatusBar 56 ───────────────────────────────────────────────────────┐
│ [profile][presence]  Instance title · Public · [people] 7  [pin][mic] 12:41 [x] │
├ NavRail 96 ┬ PageHeader 64: [back] Title ............ [HeaderActions] ┤
│ [quick]    │                                                          │
│  Quick     │  Content (padding 24)                                    │
│ [friends]  │                                                          │
│  Friends   │                                                          │
│ …          │                                                          │
└────────────┴──────────────────────────────────────────────────────────┘
```

- **StatusBar** (`StatusBar` variation, 56 high), left to right:
  1. `%ProfileButton`: 48 × 48, the own profile picture, or `profile.svg`.
  2. `%PresenceButton`: a MenuButton with a colored dot icon and the current state. Items, in this order: Online, Do not disturb, Appear offline. They call `SaveData.friends.set_status("online" | "do_not_disturb" | "offline")`. The button is disabled when friends are unavailable.
  3. `%InstanceLabel`: body text, ellipsized.
  4. `%PeopleLabel`: people icon and count, or hidden when there is no instance.
  5. Spacer.
  6. `%PinButton`: 48 × 48 `IconButton` with `pin.svg`. VR only (hidden on desktop). Toggles `vr.menu_pin_mode` between pinned (active style) and follow.
  7. `%MicButton`: 48 × 48 `IconButton`.
  8. `%Clock`: caption, `H:MM` in local 24-hour time, updated every 15 s.
  9. `%CloseButton`: 48 × 48 `IconButton`.
- **NavRail:** 96 wide. Each item is a 96 × 72 `NavButton` with a 24 px icon above a 14 px label. In compact mode the rail is 64 wide, items are 64 × 56, there are no labels, and the label becomes the tooltip.
- **PageHeader:** 64 high. `%BackButton` (48 × 48, visible only for nested pages), `%PageTitle` (`HeaderLabel`) and `%HeaderActions` (an HBox for page-specific buttons).
- **Minimum logical size:** 747 × 560. Below that, the desktop overlay switches to compact mode (§4.2).

### 3.2 Quick page

- Tile grid: columns = clamp(floor((width + 12) / 188), 2, 3). The six tiles fill 3 × 2 or 2 × 3.
- Tile minimum 176 × 132, growing to at most 280 × 200; centered when the content is wider.
- Each tile: 32 px icon, body label below it, with 16 px padding.
- Below the grid: a "Friends online" caption and `%OnlineFriends`, a row of up to 8 chips. Each chip is 40 px profile picture plus name, 48 high. Sorted by display name.
- If the list is longer, a "+N" chip opens the Friends page. If no friends are online, the row shows a muted line and an **Open Friends** link button.

### 3.3 Hosts

| Host | Size of the shell |
| --- | --- |
| PC overlay | 4:3 rectangle centered in the window's logical size, height = 86 % of it (§4.2) |
| VR tablet | `size_2d_override` 1000 × 750 ÷ `interface.ui_scale`, rendered at 1600 × 1200 |

## 4. Behavior

### 4.1 Shell navigation

- Pages, in rail order: `quick, friends, worlds, avatars, instance, settings`. Pages are created the first time they are opened and then reused. Each page keeps its own scroll and inner state while the menu is open.
- `open_page(id)` clears the nested stack. `push_page(control, title)` adds a nested page, such as a profile or the avatar detail in compact mode. `back()` pops one level and returns false at the top level.
- `reset()` (on every reopen) goes to Quick, clears nested pages and cancels profile edits (as `reset_home` does today).
- Quick actions:

| Tile | Action |
| --- | --- |
| Mute | `SaveData.voice.toggle_muted()`. Label "Mute" / "Unmute". Active style while muted. |
| Emotes | Close the menu, then `NetworkHandler.get_animation_controller().toggle_emote_menu()` (host action). |
| Change avatar | `open_page("avatars")`. The tile shows the current avatar's thumbnail if it is cached, otherwise the avatar icon. |
| Invite | `open_page("instance")` and scroll to the invite/share section. Disabled when not in an instance. |
| Respawn | Host action: `get_tree().current_scene.return_player_to_spawn(local_player)`. Disabled while `NetworkHandler.session_busy` or when the scene lacks the method. The menu stays open. |
| Mirror | `NetworkHandler.get_animation_controller().toggle_local_mirror()` (new public wrapper around `_mirror_action("__mirror_toggle__")`). Active style while the mirror is shown. |

- Status data comes from a new `NetworkHandler.get_instance_summary() -> {title, mode, people}`:
  - `title`: the world manifest title, "Welcome Island" for `default_wold`, otherwise the URL host.
  - `mode`: "Public", "Friends", "Friends+", "Request" or "Private".
  - `people`: the member count.
  - It refreshes on `active_instance_changed` and `participants_changed`. With no instance, `%InstanceLabel` shows **"Not in an instance"**.
- Online friends: contacts where `SaveData.friends.is_friend(fp)` and `status(fp) == "online"`. Refreshed on `SaveData.friends.changed`. Clicking a chip pushes that friend's profile.

### 4.2 PC overlay

- The overlay is a `CanvasLayer` at layer 10 containing `%Dim` (`overlay_dim`) and `%Shell`.
- `layout_for(size)`:
  - Normal: height h = 0.86·size.y, width w = 4/3·h, centered.
  - **Compact** when h < 560 or w > size.x: full height, width = min(size.x, 4/3·size.y), centered horizontally, rail collapsed.
  - It is re-evaluated whenever the viewport size changes.
- Input, handled in `_input` through `handle_input`:
  - `open_menue` (Esc): if a nested page is open, go back one level; otherwise close the menu. When the menu is closed, Esc opens it on Quick.
  - Keys 1–6 select rail pages unless a text field has focus.
  - A focused control with the `blocks_global_shortcuts` meta keeps Esc.
- Signals `opened` / `closed`. The desktop player sets `MOUSE_MODE_VISIBLE` / `MOUSE_MODE_CAPTURED` in response; movement and looking stay suppressed while visible (D6).
- Not draggable. No open/close animation. With reduce motion off, a 120 ms fade of `%Dim` *(tunable)* is allowed.

### 4.3 VR tablet

**Geometry**
- The screen is 0.55 × 0.4125 m × `scale_factor` and faces local +Z.
- The frame is a rounded box 2 cm larger on each side and 12 mm thick, using `surface_raised` with roughness 0.8. The screen material is unshaded.
- `%KeyboardAnchor` sits 0.06 m below the screen's lower edge, tilted 25° further toward the user.

**Placement**
- `place_initial` / `summon`: 0.55 m horizontally in front of the head's yaw direction, 0.20 m below eye height, plus the D10 side offset, turned to face the eyes (roll 0).
- After every grab release, the placement relative to the player rig is remembered (yaw and position only). The next open restores it.

**Grab zones**
- The frame border band reaches up to 4 cm outside the screen edge and ±5 cm along the normal.
- The status bar strip (top 56/750 of the screen height) also counts when grip is pressed while that hand's laser points at it.
- While the tablet is visible, `world_grab_blocked(point)` is true inside a zone, so world pickup is skipped for that hand.

**Grip input**
- OpenXR `grip` value: press at ≥ 0.7, release at ≤ 0.4 (hysteresis). The hand position is the grip pose origin.

**Moving**
- One hand: the tablet keeps the hand-relative transform from grab start.
- Two hands: `scale_factor` = start × current hand distance ÷ start distance, clamped to 0.6–1.6. The center follows the hands' midpoint, and yaw follows the line between the hands.
- Smoothing: once per physics tick, current = lerp(current, target, 1 − `smoothing`). Default `smoothing` is 0.35 *(tunable)*, or 0 with reduce motion.

**Follow mode**
- When the angle between the head's flat forward direction and the tablet direction exceeds 45°, or the tablet is more than 1.5 m away, it moves back to the summon position.
- It eases there with the same smoothing, or instantly with reduce motion.

**Pointer and touch**
- Lasers use `raycast_to_pixel` in physical viewport pixels. The viewport applies the 1.6× stretch to input. Part 8 must verify that a hit lands on the right control; if Godot does not apply the stretch to pushed input, divide the coordinates by the stretch before injecting.
- Direct touch, when enabled: the poke point is 6 cm along the controller's aim direction.
  - Hover from 3 cm in front of the screen down to 0.
  - Press from 0.8 cm in front to 2 cm behind.
  - Ignored further behind.
  - While a hand is hovering, its laser is hidden.

**Haptics** *(tunable)*
- Grab start: 0.3 amplitude, 30 ms.
- Touch press: 0.2, 15 ms.
- Scale limit reached: 0.4, 40 ms.

**Rendering**
- The tablet SubViewport uses `UPDATE_WHEN_VISIBLE`.

### 4.4 Settings page

- Row layout: `Title` (body) on the left, 45 % of the width. `Value` on the right, 40 px high. `Reset` is a 40 × 40 `IconButton` with `reset.svg` and the tooltip "Reset to default", visible only when the value differs from the default.
- Under the title, `Caption` (`CaptionLabel`) shows only when there is a description.
- `Error` appears under the row in `danger` color, only when not empty.
- `Search` sits above the category list. Typing filters across all categories by label and description (case-insensitive). Categories without matches are hidden. "No settings match "…"." appears when nothing matches. Clearing the search restores the selected category.
- A VR section in category **VR Comfort** contains `TrackerSetupButton` ("Set up VR trackers…") and `ComfortPresetButton` ("Apply comfort preset"), which applies the existing six values. The tracker button is hidden on desktop.

### 4.5 Avatar preview

**Stage**
- Camera fov 30°. The default view is yaw facing the avatar, pitch 8°, zoom 1, no pan.
- Model normalization stays as today: the longest side is scaled to 2 units, then centered.

**Input**
- Drag: yaw 0.01 rad/px, pitch 0.006 rad/px, pitch limited to −20…+45°.
- Right or middle drag: pan 0.002 × zoom units/px, offset ≤ 1.
- Wheel: ×0.85 / ×1.15, zoom 0.5–3.
- Double-click: reset.
- VR laser drag behaves the same as a left drag.

**Framing presets**

| Preset | Target | Distance |
| --- | --- | --- |
| full | bounds center | fitted (as today) |
| upper | 75 % of bounds height | 0.6 × fitted |
| face | `Head` bone if present, else 90 % of bounds height | 0.3 × fitted |

**Damping**
- `smoothing` 0.25: the per-frame fraction of the remaining difference at 60 Hz, made frame-rate independent with `1 − smoothing^(delta·60)`. It is 0 with reduce motion.

**Lighting**
- Key: directional, 1.2 energy, rotation (−35°, −30°), shadows on.
- Fill: 0.45 energy, (−10°, 140°).
- Rim: 0.8 energy, (−20°, 180°).
- Environment: background color = `preview_stage`, ambient color = `preview_stage` lightened 30 %, energy 0.4. No glow, SSAO or fog.

**Floor**
- A 1.4-unit disc at the model's feet in `surface_raised` that receives the key light's shadow. The shadow distance fits the stage.

**Idle animation**
- The idle clip from `default_animations.gd` via `avatar_animator.gd`, off by default.
- `set_idle_animation` returns false when the model has no compatible rig.

**Rendering**
- `UPDATE_ALWAYS` while easing or animating, otherwise one `UPDATE_ONCE` after each change. The existing 768 px render cap stays.

**Toolbar**
- Order: OpenFile (folder), Framing (cycles full → upper → face), ResetView (reset), Idle (emote).
- Top-right overlay, 8 px from the edges, `IconButton`s.
- Desktop: hidden until hover. VR: always visible.

### 4.6 Avatar browser

- **Sidebar:** 220 wide. Contains Search, source filter, type/format filters, and the collapsible advanced filters.
- **Results:** cards 200 × 248. Each card has a 200 × 200 thumbnail, the name (body, one line, ellipsized) and the provider (caption). Columns = max(1, floor(width ÷ 220)).
- **Detail:** a 380-wide right pane. In compact mode it is pushed as a nested page instead. It contains:
  - the preview (360 high)
  - the name (header)
  - the provider and license line
  - **Use this avatar** (PrimaryButton)
  - `%Reason` when the record cannot be used: the import-policy message, e.g. "This avatar's license does not allow redistribution."
- **Progress** uses the existing stages: download 0–70, validate 75, commit 90, done 100. It is shown inline in `%Progress` with a caption. Use is disabled while it runs. There is no cancel in this version.

### 4.7 Toasts and empty states

- **Toasts:** bottom-center of the content area, 16 px from the bottom, at most 480 wide, stacking upward with 8 px gaps. At most three; the oldest is dropped first.
  - Default durations: info 4 s, success 3 s, warning 6 s, error 8 s.
  - A 4 px left bar in the matching semantic color, or the accent for info.
  - Toasts never take focus and let clicks pass through, except their own close icon on errors.
- **Empty state:** a 48 px icon in `text_muted`, a one-sentence message (`MutedLabel`, ≤ 80 characters, ending with a period) and at most one secondary action button. Centered in its area.

## 5. Settings definitions

Registry entries are added in `register_defaults()`. All are client-local and
stored by the existing store.

| id | category | label | type / range | default | options (value: label) | order |
| --- | --- | --- | --- | --- | --- | --- |
| `interface.theme_preset` | Interface | Color scheme | enum | `graphite` | graphite: Graphite, paper: Paper, forest: Forest, sand: Sand, night: Night, high_contrast: High contrast | −4 |
| `interface.accent` | Interface | Accent color | enum | `teal` | teal: Teal, blue: Blue, amber: Amber, green: Green, rose: Rose, violet: Violet, match_highlight: Match 3D highlight | −3 |
| `interface.ui_scale` | Interface | Interface size | number 0.75–1.5, step 0.05, unit "×" | 1.0 | — | −2 |
| `interface.reduce_motion` | Interface | Reduce motion | boolean | false | — | −1 |
| `vr.menu_pin_mode` | VR Menu | Tablet placement | enum | `pinned` | pinned: Stay where I put it, follow: Follow my view | 0 |
| `vr.menu_scale` | VR Menu | Tablet size | number 0.6–1.6, step 0.05, unit "×" | 1.0 | — | 1 |
| `vr.menu_direct_touch` | VR Menu | Touch the tablet with the controller tip | boolean | false | — | 2 |
| `vr.menu_hand` | VR Menu | Tablet side | enum | `either` | left: Left, right: Right, either: Centered | 3 |

Descriptions:
- **ui_scale:** "Scales menus on desktop and the VR tablet."
- **reduce_motion:** "Turns off easing for the tablet, menus and avatar preview."
- **menu_pin_mode:** "Follow my view brings the tablet back when you turn away."
- **menu_direct_touch:** "Press buttons by touching the screen instead of pointing."

## 6. Text (copy deck)

| Where | Text |
| --- | --- |
| Status bar, no instance | Not in an instance |
| Presence items | Online · Do not disturb · Appear offline |
| Mic tooltip | Mute microphone (V) / Unmute microphone (V) — the key comes from the binding |
| Close tooltip | Close menu (Esc) on desktop; Close tablet in VR |
| Quick tiles | Mute / Unmute · Emotes · Change avatar · Invite · Respawn · Mirror |
| Friends strip, empty | None of your friends are online. — action **Open Friends** |
| Settings search, empty | No settings match "{query}". |
| Preview, empty | No avatar set. |
| Preview, loading | Loading avatar… |
| Preview, error | Could not load this avatar. Check the link and try again. — **Retry** |
| Preview, ready (desktop tooltip) | Drag to turn · right-drag to move · scroll to zoom · double-click to reset |
| Preview, local file | Local preview only. The file is not uploaded. |
| Browser, no results | No avatars match these filters. — **Clear filters** |
| Browser apply done | Avatar changed. (success toast) |
| Settings saved error | Settings could not be saved: {reason} (error toast) |

## 7. New non-GUI APIs

These are small public helpers that the GUI needs. Each is added in the part that
first uses it, with a function contract in `docs/reference`.

- `NetworkHandler.get_instance_summary() -> Dictionary` (Part 6).
- `animation_controller.toggle_local_mirror() -> bool` and `is_local_mirror_visible() -> bool` (Part 6).
- `ToastHost.find_for(node: Node) -> ToastHost`, a static ancestor lookup by meta `toast_host` (Part 12).
- `theme_service.gd` owned by `SaveData` (Part 2). It is created in `_init` after `store.configure` and applied in `_ready` after `laod_data()`, keeping the documented order.

## 8. Performance budgets *(tunable)*

- VR tablet: closed costs nothing. Open, the SubViewport is ≤ 1600 × 1200 and updates only while visible.
- Avatar preview: ≤ 768 px render and no continuous rendering when idle.
- Theme rebuild on preset change: ≤ 50 ms on the reference desktop. A short hitch is acceptable because it only happens on user action.

## 9. Compatibility and test migration

| Part | Existing tests to update in the same commit |
| --- | --- |
| 6 | `tests/microphone_settings` and `tests/profile` load `home_menue.tscn`: move them to `quick_page.tscn` / the shell. `tests/friends` and `tests/active_instance` read the `menue.tscn` / `home_menue.tscn` scene state: update the node paths. `tests/real_ui` drives the menu by node names: use the shell API. |
| 7 | `tests/real_ui` and `tests/vr_controls/desktop_fixture.gd` (desktop menu toggling). |
| 8 | `tests/vr_controls` wiring check: accept `vr_tablet.tscn`. `tests/real_ui/vr_suite.gd` panel pointer tests. `vr_gui.tscn` is deleted once it is unused. |
| 10–11 | `tests/profile` (preview size/position checks) and `tests/real_ui/avatar_suite.gd` (Apply flow without a modal). |

Kept unchanged: the `menue.tscn` path and UID, the `blocks_global_shortcuts`
and `vr_menu` metas, the profile/friends/voice service ownership, and the
avatar preview safety rules.
