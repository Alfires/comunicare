# Microphone mute and extensible settings roadmap

Scope: original roadmap and acceptance baseline, now implemented at the user's request. The implementation status below supersedes proposed architecture details where noted.

## Implementation status

UI refinement: Home microphone is now **icon-only**, retaining state-specific icons and its action/binding tooltip. Settings use a **left-hand category sidebar** (Audio, Controls, Profile) with one visible page at a time. Categories follow registry definitions automatically; switching pages cancels key capture, and registry updates preserve selection where possible. Verified microphone/settings suite: **84 passing checks**.

- Home has an upper-right microphone toggle with icon, text and binding tooltip. Default shortcut is physical **V**, including while menus are hidden; text-editor focus, IME composition, visible secondary windows and rebinding suppress the global shortcut.
- First launch starts muted. The preference persists. `SaveData` owns one registry, store and voice controller for the application's lifetime; no new autoload or separate mute boolean in each menu is required.
- Capture stops on mute, discards both buffers, gates each packet send, discards transition/disconnection backlog and removes only its owned effect. Duplicate active microphone nodes are refused. Other players' audio is unaffected.
- The settings menu renders registered boolean/number/text/enum/key-binding definitions with categories, descriptions, reset controls, validation and persistence errors. Text commits on Enter/focus loss; key conflicts are rejected; Escape cancels rebinding. Removing a definition removes its row.
- Save/load uses a versioned ConfigFile, legacy profile migration, typed defaults, debounced saves and temporary-file replacement. Corrupt/unsupported files are preserved instead of silently overwritten. Existing `SaveData.data` profile consumers remain supported. Internal temp-path/default-world load bugs are fixed.
- Ordinary settings live in `scripts/settings/settings_registry.gd:register_defaults()`. Runtime effects subscribe outside the UI: audio/profile in SaveData, mute/binding in VoiceController. New behavior still needs a consumer; no renderer/save-list edit is needed for supported control types.

Verified: **78 microphone/settings checks pass**, with real scene startup, input dispatch, responsive layout and capture/packet boundary doubles. Physical recording and a two-client desktop/VR listening check remain manual. Capture availability cannot establish whether the OS actually provides usable sound or permission merely from starting an AudioStreamMicrophone; platform-specific permission/device diagnostics remain follow-up work. A visible secondary Window blocks the shortcut conservatively, not only modal dialogs. Key binding supports one non-modifier physical key, not modifier chords or controller remapping.

The existing unrelated full-game XR autoload/VRM plugin import blockers remain outside this implementation. Do not interpret isolated headless tests as full-game VR verification.

Initial executable suite: `python3 tests/microphone_settings/run.py`. See `tests/microphone_settings/README.md` for the proposed contracts, isolation guarantees and remaining coverage. Initial result: 3 passing baseline checks, 13 expected failing acceptance checks and 4 dependent groups not run until prerequisites exist. Existing scenes run their actual `_ready()` methods; missing future APIs fail cleanly rather than producing invalid-call errors.

## Goals and behavior

1. Add a microphone toggle in the **upper-right corner of the Home menu**.
2. Pressing **V** toggles the same mute state by default, including when the menu is closed. This is toggle-to-mute, not push-to-talk.
3. Muting stops microphone capture and outgoing voice packets; unmuting never sends buffered audio recorded before/during mute.
4. Keep the button, shortcut and settings synchronized through one shared state. World changes, relay reconnects and menu reopening must not silently unmute the player.
5. Replace the fragile settings renderer with a definition-driven system: adding an ordinary setting requires one definition, not edits to rendering, loading and saving code.

Recommended defaults: microphone **muted on first launch**, persist the user's last selected mute state, and load it before capture can start. Keep these as explicit product defaults in the registry rather than relying on missing config values. The V binding is configurable. Per-instance player counts and world discovery are outside this work.

## Current implementation findings

| File | Finding |
| --- | --- |
| `scenes/GUI/home_menue.tscn` | Almost empty, with an existing VBox/HBox suitable for a header. No home-menu script or mic button. |
| `scripts/player/audio_microphone.gd` | Creates an `AudioEffectCapture`, starts an `AudioStreamMicrophone` immediately, buffers samples and sends voice. No user mute state. Desktop and VR both instantiate this scene. |
| `default_bus_layout.tres` | Separate `Microphone` and `PlayerVoices` buses already exist. Muting the microphone bus in `_ready()` prevents local monitoring; it must **not** be mistaken for disabling capture/transmission. |
| `scripts/GUI/settings_menue.gd` | A `settings_data` definition array exists but is unused. Iterating `SaveData.data` yields keys, so `i[1]` reads a character of a key, not its saved value/type. Most entries become text fields, and runtime/internal keys are exposed as editable settings. |
| `scripts/settings/save_data.gd` | Saving hardcodes four keys, so dynamically added settings are not persisted. Loading `temp_world_file_save_path` incorrectly reads the `avatar_url` key. `default_wold` is written as a constant rather than loading the stored value. The username default is only installed during load. Loading also saves immediately, which complicates recovery/migration. |
| `project.godot` | No microphone input action. Existing input actions are defined here. Preserve unrelated user edits when eventually adding the action/autoloads. |
| `scripts/GUI/menue.gd` | Handles menu input on the menu node. Do not put the global mic shortcut only here: there may be multiple menus/viewports, and hidden menus should not own global microphone behavior. |
| `scripts/startup/main.gd` | Loads SaveData before creating the player. Use this ordering to apply mute/input preferences before microphone startup. |

## Proposed architecture

Keep configuration, runtime effects and UI separate:

```text
SettingsRegistry: definitions, defaults, validation, ordering
       |
SettingsStore: validated values, migration, ConfigFile persistence
       | setting_changed(id, value)
       +--> VoiceController: owns mute state and registered capture node
       +--> Input bindings adapter: installs toggle_microphone action
       +--> Audio/profile adapters: apply their own settings
       +--> Settings menu: renders definitions and updates values

Home microphone button / global V action
       --> VoiceController.toggle_muted()
       --> SettingsStore.set_value("audio.microphone_muted", value)
```

Use a persistent controller/store (autoload or one persistent application node), not a separate mute boolean in each menu/player. `VoiceController` can derive `is_muted` from the store and emit `mute_changed(bool)` for views; it must not persist a competing copy. Effective transmission additionally depends on a working device, relay connectivity, active membership and no world transition. Being temporarily unable to transmit must not change the user's selected mute preference.

### Definition format

Prefer a typed `SettingDefinition` Resource and a registry of resources. A validated dictionary registry is acceptable initially if all access/validation is centralized. Example definitions:

```text
id: "audio.microphone_muted"
category: "Audio"
label: "Mute microphone"
description: "Stop recording and sending microphone audio."
type: boolean
default: true
persist: true
order: 10

id: "input.toggle_microphone"
category: "Controls"
label: "Toggle microphone"
type: key_binding
default: physical V
persist: true
order: 10
```

Supported initial types: boolean, bounded number (min/max/step/unit), text (length/validation), enum (stable values + display labels), and key binding. Every definition has a unique stable ID, correctly typed default, category, label, description and order. Registry validation rejects duplicate IDs, incompatible defaults, invalid bounds and unknown control types. Do not ship the current `enable_particles` example until a real runtime consumer exists.

Runtime application uses subscribers/adapters keyed by setting ID. Avoid arbitrary method-name strings such as `apply_function`, and do not make the menu execute settings effects itself. New ordinary settings need one definition; new behavior needs a consumer, and a wholly new control type needs one renderer. This keeps extension simple without hiding necessary work.

## Ordered implementation plan

### Phase 1 — Build the settings core and migrate existing values

Suggested new files: `scripts/settings/setting_definition.gd`, `settings_registry.gd`, `settings_store.gd`. Keep `SaveData` responsible for account/key handling; introduce a compatibility adapter while existing callers still read `SaveData.data`.

- Separate **user preferences/profile** (`username`, `avatar_url`, audio/input settings) from internal paths, built-in fallback assets and account keys. Internal defaults must not automatically become visible controls.
- Initialize all defaults before any consumer can access values. Load once at startup, validate saved values, install input bindings, then permit player/capture initialization.
- Use `get_value(id)`, `set_value(id, value)`, `reset_value(id)` and `reset_category(category)`. Invalid changes return an error without mutating state. Unchanged values emit nothing.
- Persist by iterating definitions marked `persist`; do not add another hardcoded list of saved keys. Use a schema version and explicit migrations.
- Migrate legacy `[UserSettings] username` and `avatar_url`. For the path bug, load the actual `temp_world_file_save_path` key or a known safe internal default, never an avatar URL. Keep the legacy `default_wold` identifier compatible with existing world code; do not rename it as a side effect of settings cleanup.
- Missing keys use defaults. Invalid individual values fall back with a warning. A missing config is normal; a corrupt/unreadable config should be reported and preserved for recovery rather than immediately overwritten on load.
- Save through a temporary file/replace strategy where supported, report failure clearly, and debounce continuous slider/text updates. Flush pending valid changes on normal shutdown. Keep secrets out of UI/exported preference files and logs.

**Exit criteria:** changing or adding a definition gives typed load/save/default behavior without editing persistence code; existing avatar/name callers still work during migration.

### Phase 2 — Centralize mute and make capture obey it

Suggested new file: `scripts/player/voice_controller.gd`; modify `scripts/player/audio_microphone.gd` and the startup wiring.

- Expose `set_muted(bool)`, `toggle_muted()`, `mute_changed(bool)`, and capture availability/error state. Read the stored preference before initializing capture; no briefly-live microphone on startup.
- Refactor the anonymous microphone player and effect into tracked fields. Register/unregister the active capture node with the controller; refuse duplicate active capture nodes or transfer ownership explicitly when swapping players.
- On mute: immediately gate `_send_voice()`, stop the microphone player, clear both `recording_buffer` and `AudioEffectCapture` samples. Keep the Microphone bus muted to prevent monitoring feedback regardless of the user preference.
- On unmute: clear both buffers first, confirm a valid capture/device, then start the stream. Do not replay stale audio. An unavailable device remains visibly unavailable even if the user selected unmuted.
- Recheck mute immediately before every packet send, not just at frame entry. Preserve existing connection/session/transition and silence checks. Do not mute `PlayerVoices` or Master: the user should still hear others while locally muted.
- On node exit, stop the stream and remove **only the capture effect owned by that node**. Avoid accumulating effects across player recreation or always assuming capture is bus effect index 0.
- On disconnect/world transition, discard queued local voice; do not send an old backlog after reconnection. Do not alter the selected mute preference.

**Exit criteria:** no voice packets while muted, no stale samples after unmute/reconnect, no duplicate capture after player recreation, shared state survives world/menu changes.

### Phase 3 — Add the Home-menu control and global V shortcut

Modify `scenes/GUI/home_menue.tscn`; add `scripts/GUI/home_menue.gd`. Add `toggle_microphone` to the input map with **physical V** as the default, following the project's physical-key movement bindings. Install saved overrides through the input adapter.

- Use the existing header HBox: an expanding spacer followed by a toggle button at the **upper-right**, with margin and adequate hit area. Use containers/anchors rather than fixed screen coordinates so desktop resize and VR viewport scaling work.
- Show a microphone/crossed-microphone icon **and text**, e.g. `Mic muted` / `Mic on`. Define `button_pressed == muted` consistently. Tooltip says `Mute microphone (V)` or `Unmute microphone (V)` using the actual binding, not a hardcoded V after rebinding.
- Subscribe on ready, read state immediately and disconnect on exit. On controller updates, use no-signal UI setters to avoid button→store→signal loops. Clicking and keyboard shortcuts call the same controller method.
- A single persistent input owner processes the action once. Toggle only on initial press, not key release or keyboard echo. Mark handled after use; multiple menu/viewports must not double-toggle.
- Ignore the shortcut during typing in `LineEdit`/`TextEdit`, IME composition, modal dialogs and key-rebinding capture. Typing the letter “v” in a username, URL or search must never change microphone state. Check the active desktop or VR SubViewport focus; relying solely on `_unhandled_input()` may still toggle in text fields that do not consume that key.
- Keep the shortcut working with the menu hidden and on other tabs. VR users can click the same button through the existing viewport input path; do not assume physical V is a VR-controller mapping. A controller binding is a later extension.
- Expose unavailable/capture errors separately from mute preference, with clear text. Do not auto-unmute after resolving an error.

**Exit criteria:** button and shortcut stay synchronized in every menu state, with no accidental toggles from text entry.

### Phase 4 — Rebuild the settings menu from the registry

Replace `settings_menue.gd`'s raw dictionary iteration and unused sample array. Give `scenes/GUI/settings_menue.tscn` a persistent layout: categories, scrollable rows, status/error area and Reset category. Suggested row scenes under `scenes/GUI/settings/` for toggle, number, text, enum and binding controls.

- Render only registered, user-visible definitions, ordered by category and order. Each row includes label, description, current value, validation feedback and Reset to default.
- A generic factory maps definition type to row scene. Bind every row to its stable setting ID, not its label or array index. Unknown types produce a clear diagnostic rather than a broken field.
- Initialize controls without emitting edits. Store updates from a shortcut/home button refresh existing rows without rebuilding the entire menu or losing focus.
- Recommended editing policy: valid audio/toggle/slider changes apply immediately; text commits on Enter or focus loss after validation; key bindings commit only after a valid capture. No global Apply/Cancel unless rollback semantics are deliberately implemented. Clearly report unsaved changes when writing fails.
- Rebinding shows the next key, ignores repeats, supports cancel/clear/reset, validates the action still has a usable binding, and warns about conflicts before replacing anything. Serialize only supported event fields; reconstruct `InputEventKey` explicitly instead of saving arbitrary objects.
- Accessibility: keyboard focus order, visible focus, tooltips/descriptions and sufficiently large VR-friendly controls. Add a setting by registering a definition; removing one removes its row without breaking older saved files.
- Removal policy: unknown/removed saved IDs are ignored and never applied. Preserve them only in a versioned migration bucket if downgrade support is desired; otherwise discard on the next successful save. Never recycle an old ID for an incompatible meaning/type.

**Exit criteria:** adding/removing a normal setting needs no renderer or save/load edits, and all currently exposed settings have real application behavior.

## Test plan — write before each phase

Use an isolated temporary Godot project, following `tests/public_discovery/run.py`. No physical microphone, external relay, real user settings, or full VR/VRM startup required for automated checks. Add test seams at device/packet/config boundaries, **not** by skipping the entire `_ready()` path; the discovery `peerŝ` regression demonstrated why startup coverage matters.

| Area | Required checks |
| --- | --- |
| Registry | Duplicate IDs, wrong default type, bad bounds/enum, unknown row type rejected. Add/remove a synthetic definition: row and persistence follow automatically. |
| Store | Defaults before startup consumers; save/reload every supported type; invalid saved values; corrupt/missing files; write failures; unchanged values emit no signals; reset one/category; removed/unknown keys safe. |
| Migration | Legacy username/avatar preserved; temp path never becomes avatar URL; account key unaffected; old world identifier retained; no destructive save during failed load. |
| Mute state | Recommended first-run mute; saved preference restored before capture; button/shortcut/settings share one source; scene reload/reconnect do not reset it. |
| Capture/privacy | While muted no microphone start and no packets; muting live capture stops stream and clears both buffers; unmute sends only fresh samples; direct send calls still gated; inbound voices remain audible. |
| Capture lifecycle | Missing bus/device, failed initialization, duplicate node, exit cleanup and player replacement; remove only owned effects; no backlog across transitions/disconnects. |
| Input | V press once toggles once; release/repeat do not; other keys ignored; menu closed works; text/IME/modal/rebind focus suppresses toggling; multiple viewports do not duplicate handling. |
| Home UI | Instantiate actual scene and run real ready; top-right layout at different sizes; initial button state, click routing, state update without signal loop, teardown and reopen. |
| Settings UI | Actual ready renders supported types; opening saves nothing; invalid text remains uncommitted; external mute changes update toggle; reset, category scroll/focus and errors; no duplicate subscriptions on reopen. |
| Binding persistence | Default V; rebind survives restart; tooltip follows binding; malformed saved events rejected; cancel/conflict/reset semantics verified. |
| Integration | Real store + controller + Home/Settings scenes with fake capture/packet sink: click, V and settings produce the same state and packet suppression. Dedicated relay does not initialize microphone/input handling. |

Manual release checks: two clients in one public instance confirm the remote listener stops hearing voice immediately after click/V; speaker can still hear others; unmute has no recorded backlog. Check Linux audio devices, desktop menu open/closed, typing a URL containing v, world changes, reconnects, restart with muted preference, and actual VR viewport/controller clicks.

## Delivery order and boundaries

1. Registry/store/migration and tests.
2. Shared voice state + capture gating/lifecycle and tests.
3. Home upper-right button + default V action and input/startup tests.
4. Definition-driven settings UI + rebinding and UI tests.
5. Two-client desktop/VR verification, documentation and cleanup of compatibility adapters once all old consumers migrate.

No protocol change is required to stop local voice packets. A network-visible mute badge for other players, push-to-talk, microphone device selection and voice moderation are separate follow-ups. The existing full-project XR autoload/VRM import blockers must be resolved before claiming full-game/VR verification; they are not silently included in this plan.
