# Microphone and settings acceptance tests

After profile separation: **88 checks pass**. Profile edits now belong exclusively to the separate profile menu (`tests/profile/`); general Settings contains Audio, Controls and Interface. Text-renderer tests use a synthetic non-profile definition. New gain/threshold tests verify their actual capture behavior.

Run from the repository root:

```sh
python3 tests/microphone_settings/run.py
# Optional:
GODOT=/path/to/godot python3 tests/microphone_settings/run.py
```

Requires Python 3 and Godot 4. Tests run in a disposable project, with no microphone device, external network, VR startup or real user config access. Actual Home/Settings scenes execute their real `_ready()` methods. The legacy loader writes only a fixture config inside the temporary project. Production input definitions are copied unchanged; the runner does not invent a V binding.

Exit codes: **0** all assertions pass; **1** expected acceptance failures; **2** import/runtime errors. Missing proposed scripts/methods fail prerequisite checks; dependent behavioral groups are explicitly counted as not run, not reported as passing. No implementation is provided by fixtures.

Initial result: **3 passing baseline checks, 13 failing acceptance checks, 4 dependent groups not run** because their feature prerequisites are absent. The guarded behavioral assertions become active once those APIs exist.

Current implementation result: **78 passed, 0 failed, 0 dependent groups skipped**. Includes real Home/Settings startup, a real settings store/controller, actual viewport key dispatch and focus, top-right positioning at two sizes, muted direct-send suppression with a live-session fixture, stream stop/start, buffer clearing, duplicate-capture rejection, effect ownership cleanup, rebinding/conflicts, dynamic setting rows, corrupt-file preservation and typed persistence. The fake capture replaces only the device stream and final packet sink; no physical microphone is opened.

## Current coverage

- Actual V input action/default, Home microphone toggle presence/wiring/text.
- Actual settings initialization, correct displayed values, internal-setting exclusion, scroll container, no save on open.
- Legacy config migration bugs: avatar URL used as temp path, saved world overwritten.
- Guarded registry/store contracts: extension/removal, defaults, duplicate IDs, invalid types/bounds, validation, change signals, ConfigFile round-trip and resets.
- Guarded voice contracts: shared mute state, safe initial default, initial key press vs echo/release, suppression during text/modal input and unrelated keys.
- Guarded capture contracts: explicit mute, local buffer clearing and disconnected-send baseline.

## Proposed interfaces used by the guarded tests

These make the roadmap executable, but do not prescribe internal architecture. If implementation uses typed Resources instead of dictionaries, adapt test setup—not the behavioral assertions.

- `SettingsRegistry.new()`: `register_setting(Dictionary) -> bool`, `unregister_setting(id)`, `get_definitions() -> Array`. Definition types here use `number`, `boolean`, `text`, `enum`, `key_binding`.
- `SettingsStore.new()`: `configure(registry, config_path)` installs defaults; `get_value`, `set_value -> bool`, `reset_value`, `reset_category`, `save_settings -> bool`, `load_settings -> bool`; signal `setting_changed(id, value)`.
- `VoiceController.new()`: first-launch state muted; `is_muted() -> bool`, `set_muted(bool)`, `toggle_muted()`, signal `mute_changed(bool)`; `handle_toggle_input(event, suppressed: bool)` applies the configured action and ignores releases/echo/suppressed events. The persistent input owner computes suppression from actual focus/modal/rebind state.
- Capture node: `set_muted(bool)`, `is_muted() -> bool`; muting discards its existing `recording_buffer`. Tests guard these APIs instead of attempting invalid calls.

## Follow-up coverage required with implementation

Still requires manual or platform-specific checks: physical microphone permissions/device loss, actual recorded-buffer freshness under real audio-driver concurrency, IME composition, VR viewport/controller interaction, multiple-window input behavior, and two-client listening tests. The isolated suite does not launch the full game or validate the bundled VRM/XR addons. Full tests for failed shutdown saves and platform-specific atomic replacement behavior are also follow-ups.
