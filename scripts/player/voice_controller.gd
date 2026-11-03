extends Node

signal mute_changed(muted: bool)
signal availability_changed(message: String)
var store
var fallback_muted := true
var capture_node: Node
var availability := "Microphone unavailable"
var input_blocked := false

func configure(settings):
	if store != null and store.setting_changed.is_connected(_on_setting_changed):
		store.setting_changed.disconnect(_on_setting_changed)
	store = settings
	store.setting_changed.connect(_on_setting_changed)
	_on_setting_changed("audio.microphone_muted", is_muted())
	_on_setting_changed("input.toggle_microphone", store.get_value("input.toggle_microphone"))
	_on_setting_changed("input.toggle_animation_menu", store.get_value("input.toggle_animation_menu"))

func _ready():
	set_process_input(not ("--relay" in OS.get_cmdline_args() or OS.has_feature("dedicated_server")))

func is_muted() -> bool:
	return bool(store.get_value("audio.microphone_muted")) if store != null else fallback_muted

func set_muted(value: bool):
	if store != null:
		store.set_value("audio.microphone_muted", value)
	elif fallback_muted != value:
		fallback_muted = value
		_on_setting_changed("audio.microphone_muted", value)

func toggle_muted():
	set_muted(not is_muted())

func _on_setting_changed(id: String, value: Variant):
	if id == "audio.microphone_muted":
		if is_instance_valid(capture_node):
			capture_node.set_muted(bool(value))
		mute_changed.emit(bool(value))
	elif id in ["input.toggle_microphone", "input.toggle_animation_menu"]:
		var action = id.trim_prefix("input.")
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = int(value)
		InputMap.action_add_event(action, event)

func register_capture(node: Node) -> bool:
	if is_instance_valid(capture_node) and capture_node != node:
		return false
	capture_node = node
	node.set_muted(is_muted())
	return true

func unregister_capture(node: Node):
	if capture_node == node:
		capture_node = null
		set_availability("Microphone unavailable")

func set_availability(message: String):
	availability = message
	availability_changed.emit(message)

func binding_text() -> String:
	if InputMap.has_action("toggle_microphone"):
		var events = InputMap.action_get_events("toggle_microphone")
		if not events.is_empty():
			return events[0].as_text().replace(" (Physical)", "")
	return "Unbound"

func handle_toggle_input(event: InputEvent, suppressed: bool) -> bool:
	if suppressed or not event is InputEventKey or not event.pressed or event.echo:
		return false
	if InputMap.has_action("toggle_microphone") and event.is_action_pressed("toggle_microphone"):
		toggle_muted()
		return true
	return false

func _focus_blocks_input(node: Node) -> bool:
	if node is Control and node.is_visible_in_tree() and node.get_meta("blocks_global_shortcuts", false):
		return true
	if node is Viewport:
		var focus = node.gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return true
	if node is Window and node != get_tree().root and node.visible:
		return true
	for child in node.get_children():
		if _focus_blocks_input(child):
			return true
	return false

func _input(event: InputEvent):
	var composing = DisplayServer.has_feature(DisplayServer.FEATURE_IME) and not DisplayServer.ime_get_text().is_empty()
	var suppressed = input_blocked or composing \
		or _focus_blocks_input(get_tree().root)
	if handle_toggle_input(event, suppressed):
		get_viewport().set_input_as_handled()

func _notification(what):
	if what == NOTIFICATION_PREDELETE and store != null and is_instance_valid(store) \
		and store.setting_changed.is_connected(_on_setting_changed):
		store.setting_changed.disconnect(_on_setting_changed)
