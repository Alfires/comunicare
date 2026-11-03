extends SceneTree

var passed := 0
var failed := 0
var skipped := 0
const REGISTRY = "res://scripts/settings/settings_registry.gd"
const STORE = "res://scripts/settings/settings_store.gd"
const VOICE = "res://scripts/player/voice_controller.gd"

func _initialize():
	call_deferred("run")

func check(ok: bool, title: String):
	if ok:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		print("FAIL: ", title)

func require_methods(object: Object, methods: Array, title: String) -> bool:
	var missing: Array = []
	for method in methods:
		if not object.has_method(method):
			missing.append(method)
	check(missing.is_empty(), title + ("; missing: " + str(missing) if not missing.is_empty() else ""))
	return missing.is_empty()

func optional_script(path: String, title: String):
	var exists = ResourceLoader.exists(path)
	check(exists, title)
	return load(path).new() if exists else null

func dispose(object):
	if object is Node:
		object.free()

func run():
	test_default_binding()
	test_home_scene()
	await test_home_in_tab_panel()
	test_current_settings_scene()
	test_category_navigation()
	test_legacy_persistence()
	test_registry_store()
	test_voice_controller()
	test_capture_contract()
	test_error_popup()
	test_store_recovery_and_types()
	await test_shared_ui_and_capture()
	print("\nMicrophone/settings: %d passed, %d failed; %d dependent groups not run" % [passed, failed, skipped])
	quit(1 if failed else 0)

func test_default_binding():
	var exists = InputMap.has_action("toggle_microphone")
	check(exists, "production input map defines toggle_microphone")
	var found_v := false
	if exists:
		for event in InputMap.action_get_events("toggle_microphone"):
			if event is InputEventKey and event.physical_keycode == KEY_V:
				found_v = true
	check(found_v, "toggle_microphone defaults to physical V")

func test_error_popup():
	var parent = Control.new()
	root.add_child(parent)
	var helper = load("res://scripts/GUI/error_popup.gd")
	var popup = helper.show_error(parent, "Could not save settings.")
	check(popup.visible and popup.message_label.text == "Could not save settings.", "errors open a visible popup with the actual message")
	check(helper.show_error(parent, "Another error") == popup and parent.get_child_count() == 1,
		"repeated errors reuse a single popup")
	var voice = root.get_node("SaveData").voice
	var before = voice.is_muted()
	voice._input(key_event(true))
	check(voice.is_muted() == before, "error popup suppresses global microphone shortcut")
	popup.accept_button.pressed.emit()
	check(not popup.visible, "OK dismisses error popup")
	parent.free()

func descendants(node: Node, type_name: String) -> Array:
	return node.find_children("*", type_name, true, false)

func test_home_scene():
	var scene = load("res://scenes/GUI/home_menue.tscn").instantiate()
	root.add_child(scene) # Do not suppress production _ready().
	var toggles: Array = []
	for button in descendants(scene, "BaseButton"):
		if button.toggle_mode and ("mic" in button.name.to_lower() or "mic" in str(button.get("text")).to_lower()):
			toggles.append(button)
	check(toggles.size() == 1, "actual Home scene has exactly one microphone toggle")
	if toggles.size() == 1:
		var button: BaseButton = toggles[0]
		check(not button.tooltip_text.is_empty(), "microphone button explains its action/binding")
		check(str(button.get("text")).is_empty() and button.icon != null, "Home microphone is icon-only with no status text")
		check(not button.get_signal_connection_list("toggled").is_empty()
			or not button.get_signal_connection_list("pressed").is_empty(), "real Home ready wires microphone button")
	else:
		skipped += 1
	scene.free()

func test_home_in_tab_panel():
	var menu = TabContainer.new()
	menu.set_script(load("res://scripts/GUI/menue.gd"))
	menu.size = Vector2(800, 600)
	# Reproduce an inherited theme's inset instead of testing Home in isolation.
	var padded = StyleBoxFlat.new()
	padded.content_margin_right = 12.0
	menu.add_theme_stylebox_override("panel", padded)
	var home = load("res://scenes/GUI/home_menue.tscn").instantiate()
	menu.add_child(home)
	root.add_child(menu)
	await process_frame
	await process_frame
	var button: Button = home.get_node("VBoxContainer/HBoxContainer/Microphone")
	check(is_equal_approx(button.get_global_rect().end.x, menu.get_global_rect().end.x),
		"microphone meets outer menu edge even with inherited tab-panel padding")
	check(padded.content_margin_right == 12.0, "menu padding fix does not mutate shared theme style")
	menu.free()

func test_current_settings_scene():
	var save = root.get_node("SaveData")
	var before = save.saves
	var scene = load("res://scenes/GUI/settings_menue.tscn").instantiate()
	root.add_child(scene) # Exercise actual renderer and ready, including legacy bugs.
	check(save.saves == before, "opening Settings does not save or mutate preferences")
	var shown_values: Array = []
	for edit in descendants(scene, "LineEdit"):
		shown_values.append(edit.text)
	check(not scene.controls.has("profile.username"), "general Settings no longer edits profile name")
	check(not scene.controls.has("profile.avatar_url"), "general Settings no longer edits profile avatar")
	var exposed: Array = []
	for label in descendants(scene, "Label"):
		if label.text in ["temp_world_file_save_path", "default_avatar", "default_wold"]:
			exposed.append(label.text)
	check(exposed.is_empty(), "settings UI does not expose internal paths/fallback assets")
	check(not descendants(scene, "ScrollContainer").is_empty(), "settings rows live in a scrollable layout")
	scene.free()

func test_category_navigation():
	var save = root.get_node("SaveData")
	var scene = load("res://scenes/GUI/settings_menue.tscn").instantiate()
	root.add_child(scene)
	check(InputMap.has_action("toggle_animation_menu") and InputMap.action_get_events("toggle_animation_menu")[0].physical_keycode == KEY_B,
		"emote menu defaults to physical B through registry and InputMap")
	check(scene.controls.has("input.toggle_animation_menu"), "Settings exposes rebindable emote menu control")
	check(scene.category_buttons.keys() == ["Assets", "Audio", "Controls", "Interface", "VR Comfort", "VR Movement"],
		"left sidebar lists registry category names")
	check(scene.category_pages.Assets.visible and not scene.category_pages.Audio.visible and not scene.category_pages.Controls.visible
		and not scene.category_pages.Interface.visible, "only initial category page is visible")
	scene.category_buttons.Controls.pressed.emit()
	check(scene.selected_category == "Controls" and scene.category_pages.Controls.visible
		and not scene.category_pages.Audio.visible and scene.category_buttons.Controls.button_pressed,
		"clicking sidebar selects a single category page")
	scene._begin_binding("input.toggle_microphone")
	scene.category_buttons.Interface.pressed.emit()
	check(scene.binding_id.is_empty() and not save.voice.input_blocked,
		"switching category cancels key capture")
	var definition = {"id": "test.sidebar", "category": "Video", "label": "Example",
		"type": "boolean", "default": false}
	save.registry.register_setting(definition)
	check(scene.selected_category == "Interface" and scene.category_buttons.has("Video"),
		"dynamic registry update preserves selection and adds category tab")
	scene.category_buttons.Video.pressed.emit()
	save.registry.unregister_setting("test.sidebar")
	check(not scene.category_buttons.has("Video") and scene.category_pages.has(scene.selected_category)
		and scene.category_pages[scene.selected_category].visible,
		"removing selected category falls back to an available page")
	scene.free()

func test_legacy_persistence():
	var save = load("res://scripts/settings/save_data.gd").new()
	# Never call account/key generation or touch the real user configuration.
	save.settings_path = "res://legacy-test.cfg"
	var config = ConfigFile.new()
	config.set_value("UserSettings", "username", "Legacy user")
	config.set_value("UserSettings", "avatar_url", "https://example.test/legacy.vrm")
	config.set_value("UserSettings", "temp_world_file_save_path", "user://worlds/custom.cne")
	config.set_value("UserSettings", "default_wold", "PreservedWorld")
	config.save(save.settings_path)
	save.laod_data()
	check(save.data.username == "Legacy user" and save.data.avatar_url == "https://example.test/legacy.vrm",
		"legacy load preserves username and avatar")
	check(save.data.temp_world_file_save_path == "user://worlds/custom.cne",
		"legacy load reads temp path from its own key, not avatar_url")
	check(save.data.default_wold == "PreservedWorld", "legacy load preserves saved default world")
	save.free()

# Proposed small contracts are documented in README.md. Guard missing APIs so
# not-yet-implemented features produce assertions, not invalid-call errors.
func test_registry_store():
	var registry = optional_script(REGISTRY, "definition-driven settings registry exists")
	var store = optional_script(STORE, "typed persistent settings store exists")
	if registry == null or store == null:
		skipped += 1
		dispose(registry)
		dispose(store)
		return
	var registry_ok = require_methods(registry, ["register_setting", "unregister_setting", "get_definitions"], "registry extension API")
	var store_ok = require_methods(store, ["configure", "get_value", "set_value", "reset_value", "reset_category", "save_settings", "load_settings"], "store contract API")
	if not registry_ok or not store_ok:
		skipped += 1
		dispose(registry)
		dispose(store)
		return
	var definition = {"id": "test.volume", "category": "Test", "label": "Volume",
		"type": "number", "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.1, "persist": true}
	check(registry.register_setting(definition), "register a new ordinary setting in one definition")
	check(not registry.register_setting(definition), "duplicate setting IDs rejected")
	var invalid = definition.duplicate(true)
	invalid.id = "test.invalid"
	invalid.default = "not a number"
	check(not registry.register_setting(invalid), "wrong default type rejected")
	invalid.default = 0.5
	invalid.min = 2.0
	check(not registry.register_setting(invalid), "inverted numeric bounds rejected")
	var changes: Array = []
	check(store.has_signal("setting_changed"), "store publishes setting_changed")
	if store.has_signal("setting_changed"):
		store.connect("setting_changed", func(id, value): changes.append([id, value]))
	store.configure(registry, "res://settings-test.cfg")
	check(store.get_value("test.volume") == 0.5, "registered defaults available before loading a file")
	check(store.set_value("test.volume", 0.8) and store.get_value("test.volume") == 0.8, "valid typed setting change applies")
	var count = changes.size()
	store.set_value("test.volume", 0.8)
	check(changes.size() == count, "unchanged values do not emit duplicate changes")
	check(not store.set_value("test.volume", "bad") and store.get_value("test.volume") == 0.8, "invalid type does not mutate setting")
	check(not store.set_value("test.volume", 9.0), "out-of-range value rejected")
	check(store.save_settings(), "registered setting persists without a hardcoded save key")
	store.set_value("test.volume", 0.2)
	check(store.load_settings() and store.get_value("test.volume") == 0.8, "registered setting round-trips through ConfigFile")
	store.reset_value("test.volume")
	check(store.get_value("test.volume") == 0.5, "individual reset restores registered default")
	store.set_value("test.volume", 0.9)
	store.reset_category("Test")
	check(store.get_value("test.volume") == 0.5, "category reset restores defaults")
	registry.unregister_setting("test.volume")
	var remains := false
	for value in registry.get_definitions():
		if value.id == "test.volume":
			remains = true
	check(not remains, "removing a definition removes it from exposed settings")
	dispose(store)
	dispose(registry)

func key_event(pressed: bool, repeat: bool = false) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = KEY_V
	event.pressed = pressed
	event.echo = repeat
	return event

func test_voice_controller():
	var voice = optional_script(VOICE, "shared persistent voice controller exists")
	if voice == null:
		skipped += 1
		return
	if not require_methods(voice, ["is_muted", "set_muted", "toggle_muted", "handle_toggle_input"], "voice state/input contract API"):
		skipped += 1
		dispose(voice)
		return
	check(voice.has_signal("mute_changed"), "voice controller publishes mute_changed")
	check(voice.is_muted(), "unconfigured first-launch microphone is muted")
	voice.set_muted(true)
	voice.toggle_muted()
	check(not voice.is_muted(), "toggle unmutes shared state")
	voice.set_muted(true)
	voice.handle_toggle_input(key_event(true), false)
	check(not voice.is_muted(), "initial V press toggles microphone")
	voice.handle_toggle_input(key_event(true, true), false)
	check(not voice.is_muted(), "held-key echo does not toggle microphone again")
	voice.handle_toggle_input(key_event(false), false)
	check(not voice.is_muted(), "key release does not toggle microphone")
	voice.handle_toggle_input(key_event(true), true)
	check(not voice.is_muted(), "typing/modal/rebind input suppression prevents toggle")
	var other = key_event(true)
	other.physical_keycode = KEY_B
	voice.handle_toggle_input(other, false)
	check(not voice.is_muted(), "unbound key does not toggle microphone")
	dispose(voice)

func test_capture_contract():
	var capture = load("res://scripts/player/audio_microphone.gd").new()
	# Do not enter the tree: unit test must never open physical audio hardware.
	var supported = require_methods(capture, ["set_muted", "is_muted"], "capture supports explicit mute state")
	if supported:
		capture.recording_buffer = PackedFloat32Array([0.4, 0.5, 0.6])
		capture.set_muted(true)
		check(capture.is_muted() and capture.recording_buffer.is_empty(), "muting clears queued local samples immediately")
		capture.set_muted(false)
		check(capture.recording_buffer.is_empty(), "unmuting never restores stale microphone samples")
	else:
		skipped += 1
	var before = AudioServer.get_bus_count()
	capture._send_voice(PackedFloat32Array([0.8]))
	check(AudioServer.get_bus_count() == before, "disconnected send does not create audio buses or crash")
	capture.free()

func test_store_recovery_and_types():
	var registry = load(REGISTRY).new()
	for definition in [
		{"id": "test.toggle", "type": "boolean", "default": true},
		{"id": "test.text", "type": "text", "default": "hello", "max_length": 10},
		{"id": "test.enum", "type": "enum", "default": "a", "options": {"a": "A", "b": "B"}},
		{"id": "test.key", "type": "key_binding", "default": KEY_V},
	]:
		definition.category = "Test"
		definition.label = definition.id
		registry.register_setting(definition)
	var store = load(STORE).new()
	store.configure(registry, "res://typed-test.cfg")
	check(store.load_settings() and store.get_value("test.toggle"), "missing config uses defaults")
	store.set_value("test.toggle", false)
	store.set_value("test.text", "saved")
	store.set_value("test.enum", "b")
	store.set_value("test.key", KEY_M)
	store.save_settings()
	var second = load(STORE).new()
	second.configure(registry, store.config_path)
	second.load_settings()
	check(second.get_value("test.toggle") == false and second.get_value("test.text") == "saved"
		and second.get_value("test.enum") == "b" and second.get_value("test.key") == KEY_M,
		"boolean/text/enum/key values all survive restart")
	check(not second.set_value("test.enum", "unknown") and not second.set_value("test.key", -1), "invalid enum and key values rejected")
	var file = FileAccess.open("res://corrupt.cfg", FileAccess.WRITE)
	file.store_string("[broken\nnot config")
	file.close()
	second.config_path = "res://corrupt.cfg"
	# ConfigFile logs a native error for intentionally malformed input. Suppress
	# only that expected log; assertions still verify recovery and file contents.
	Engine.print_error_messages = false
	var corrupt_loaded: bool = second.load_settings()
	Engine.print_error_messages = true
	check(not corrupt_loaded and not second.save_settings()
		and FileAccess.get_file_as_string("res://corrupt.cfg") == "[broken\nnot config",
		"corrupt config is reported and never overwritten")
	second.configure(registry, "res://missing-directory/settings.cfg")
	check(not second.save_settings() and not second.last_error.is_empty(), "write failures are reported to callers")
	store.free()
	second.free()

func test_shared_ui_and_capture():
	var save = root.get_node("SaveData")
	var network = root.get_node("NetworkHandler")
	AudioServer.set_bus_layout(load("res://default_bus_layout.tres"))
	save.voice.set_muted(true)
	var home = load("res://scenes/GUI/home_menue.tscn").instantiate()
	var settings = load("res://scenes/GUI/settings_menue.tscn").instantiate()
	root.add_child(home)
	root.add_child(settings)
	var button: Button = home.get_node("VBoxContainer/HBoxContainer/Microphone")
	var toggle: CheckButton = settings.controls["audio.microphone_muted"]
	var capture = load("res://fixtures/capture.gd").new()
	root.add_child(capture)
	check(capture.is_muted() and not capture.audio_player.playing, "real capture ready does not start recording while muted")
	var connection = ENetConnection.new()
	connection.create_host(1)
	network.peer = RelayPeer.new()
	network.peer.peer = connection.connect_to_host("127.0.0.1", 9)
	network.peer.is_connected_to_relay = true
	network.current_session_id = "test-room"
	capture._send_voice(PackedFloat32Array([0.8]))
	check(capture.packets.is_empty(), "muted direct send emits zero packets even with valid session")
	button.button_pressed = false
	check(not save.voice.is_muted() and not toggle.button_pressed and capture.audio_player.playing,
		"Home click updates store, settings toggle and capture stream together")
	capture._send_voice(PackedFloat32Array([0.8]))
	check(capture.packets.size() == 1, "unmuted fresh voice reaches packet sink")
	save.store.set_value("audio.microphone_gain", 2.0)
	capture._send_voice(PackedFloat32Array([0.8]))
	check(capture.packets.back()[0] == 1.0, "microphone gain applies with safe sample clamping")
	save.store.set_value("audio.voice_threshold", 0.1)
	var packets_before = capture.packets.size()
	capture._send_voice(PackedFloat32Array([0.001]))
	check(capture.packets.size() == packets_before, "configured threshold suppresses quiet samples")
	save.store.reset_value("audio.microphone_gain")
	save.store.reset_value("audio.voice_threshold")
	capture.packets.pop_back()
	capture.recording_buffer = PackedFloat32Array([0.5, 0.6])
	toggle.button_pressed = true
	check(save.voice.is_muted() and button.button_pressed and not capture.audio_player.playing
		and capture.recording_buffer.is_empty() and capture.audio_capture.get_frames_available() == 0,
		"Settings mute stops capture, clears both buffers and synchronizes Home")
	capture._send_voice(PackedFloat32Array([0.9]))
	check(capture.packets.size() == 1, "muting live stream suppresses subsequent packets")
	save.voice.handle_toggle_input(key_event(true), false)
	check(not button.button_pressed and not toggle.button_pressed and capture.recording_buffer.is_empty(),
		"V shortcut updates both UIs without replaying buffered voice")
	network.session_busy = true
	capture.recording_buffer = PackedFloat32Array([0.7])
	capture._process(0)
	capture._send_voice(PackedFloat32Array([0.9]))
	check(capture.recording_buffer.is_empty() and capture.packets.size() == 1, "world transition discards backlog and blocks outgoing voice")
	network.session_busy = false
	var voice_bus = AudioServer.get_bus_index("PlayerVoices")
	check(not AudioServer.is_bus_mute(voice_bus), "local mic mute never mutes incoming voices")
	var bus = AudioServer.get_bus_index("Microphone")
	var unrelated = AudioEffectAmplify.new()
	AudioServer.add_bus_effect(bus, unrelated, 0)
	var before = AudioServer.get_bus_effect_count(bus)
	var duplicate = load("res://fixtures/capture.gd").new()
	root.add_child(duplicate)
	check(duplicate.audio_player == null and save.voice.capture_node == capture, "duplicate player cannot create another active microphone")
	duplicate.free()
	capture.free()
	check(AudioServer.get_bus_effect_count(bus) == before - 1 and AudioServer.get_bus_effect(bus, 0) == unrelated,
		"capture teardown removes only its own effect")
	settings._begin_binding("input.toggle_microphone")
	check(save.voice.input_blocked, "key rebinding suppresses global mic shortcut")
	var key = key_event(true)
	key.physical_keycode = KEY_M
	settings._input(key)
	check(not save.voice.input_blocked and save.store.get_value("input.toggle_microphone") == KEY_M
		and "M" in button.tooltip_text, "rebinding changes action and Home tooltip")
	save.voice.set_muted(true)
	save.voice.handle_toggle_input(key_event(true), false)
	check(save.voice.is_muted(), "old V binding no longer toggles after rebinding")
	save.voice.handle_toggle_input(key, false)
	check(not save.voice.is_muted(), "new binding toggles shared mute state")
	save.store.reset_value("input.toggle_microphone")
	settings._begin_binding("input.toggle_microphone")
	var conflict = key_event(true)
	conflict.physical_keycode = KEY_W
	settings._input(conflict)
	check(save.voice.input_blocked and not settings.errors["input.toggle_microphone"].text.is_empty(), "conflicting key is rejected without losing binding capture")
	settings._cancel_binding()
	# Keep generic text-control regression coverage with a non-profile setting.
	save.registry.register_setting({"id": "test.text", "category": "Test", "label": "Test text", "type": "text", "default": "Test user", "min_length": 1})
	settings.select_category("Test")
	var edit: LineEdit = settings.controls["test.text"]
	edit.grab_focus()
	await process_frame
	var previous = save.voice.is_muted()
	root.push_input(key_event(true))
	check(save.voice.is_muted() == previous, "actual focused text editor suppresses global V")
	edit.release_focus()
	home.hide()
	settings.hide()
	root.push_input(key_event(true))
	check(save.voice.is_muted() != previous, "global V toggles with Home and Settings hidden")
	home.show()
	settings.show()
	for dimensions in [Vector2i(1000, 700), Vector2i(640, 480)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var bounds: Rect2 = button.get_global_rect()
		check(is_equal_approx(bounds.end.x, home.get_global_rect().end.x)
			and is_equal_approx(bounds.position.y, home.global_position.y),
			"microphone stays top-right at " + str(dimensions))
	edit.text = ""
	edit.text_submitted.emit("")
	check(save.store.get_value("test.text") == "Test user" and not settings.errors["test.text"].text.is_empty(), "invalid text remains uncommitted with feedback")
	settings._reset_value("test.text")
	edit.text = ""
	edit.text_submitted.emit("")
	settings._reset_value("test.text")
	check(edit.text == "Test user" and settings.errors["test.text"].text.is_empty(),
		"Reset clears invalid uncommitted text even when stored value already equals default")
	var def = {"id": "test.dynamic", "category": "Test", "label": "Dynamic setting", "type": "boolean", "default": false}
	save.registry.register_setting(def)
	check(settings.controls.has("test.dynamic"), "registering a setting automatically creates its UI row")
	save.registry.unregister_setting("test.dynamic")
	check(not settings.controls.has("test.dynamic"), "unregistering a setting automatically removes its row")
	save.voice.set_muted(true)
	save.store.save_settings()
	save.voice.set_muted(false)
	save.store.load_settings()
	check(save.voice.is_muted() and button.button_pressed, "saved mute preference restores through store and UI")
	settings.free()
	home.free()
	await process_frame
	check(save.voice.mute_changed.get_connections().is_empty(), "Home teardown removes mute subscription")
	network.peer = null
	network.current_session_id = ""
	connection.destroy()
