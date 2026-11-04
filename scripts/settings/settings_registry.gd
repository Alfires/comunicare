extends RefCounted

signal definitions_changed
var definitions: Dictionary = {}

func register_setting(definition: Dictionary) -> bool:
	var id = definition.get("id")
	if not id is String or id.is_empty() or definitions.has(id) \
		or not definition.get("category") is String or not definition.get("label") is String:
		return false
	if definition.get("type") == "number":
		if not _number(definition.get("min")) or not _number(definition.get("max")) \
			or definition.min > definition.max or not _number(definition.get("step", 1)) \
			or definition.get("step", 1) <= 0:
			return false
	if not validate(definition, definition.get("default")):
		return false
	definitions[id] = definition.duplicate(true)
	definitions_changed.emit()
	return true

func unregister_setting(id: String):
	if definitions.erase(id):
		definitions_changed.emit()

func get_definitions() -> Array:
	var result = definitions.values().duplicate(true)
	result.sort_custom(func(a, b):
		if a.category != b.category:
			return a.category < b.category
		return a.get("order", 0) < b.get("order", 0))
	return result

func get_definition(id: String) -> Dictionary:
	return definitions.get(id, {}).duplicate(true)

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func validate(definition: Dictionary, value: Variant) -> bool:
	match definition.get("type"):
		"boolean":
			return value is bool
		"number":
			return _number(value) and value >= definition.get("min", -INF) and value <= definition.get("max", INF)
		"text":
			if not value is String or value.length() < definition.get("min_length", 0) or value.length() > definition.get("max_length", 4096):
				return false
			if definition.get("format") == "url":
				return (value.begins_with("https://") or value.begins_with("http://")) and not " " in value and not "\n" in value
			return true
		"enum":
			return definition.get("options") is Dictionary and definition.options.has(value)
		"key_binding":
			return value is int and value > 0 and value < (1 << 23) \
				and value not in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] \
				and not OS.get_keycode_string(value).is_empty()
	return false

func register_defaults():
	for definition in [
		{"id": "vr.locomotion_mode", "category": "VR Movement", "label": "Locomotion", "type": "enum", "options": {"smooth": "Smooth", "teleport": "Point and teleport"}, "default": "smooth", "order": -1},
		{"id": "vr.head_clip_fade", "category": "VR Comfort", "label": "Fade when head intersects world geometry", "type": "boolean", "default": true, "order": 3},
		{"id": "vr.turn_mode", "category": "VR Movement", "label": "Turning", "type": "enum", "options": {"snap": "Snap", "smooth": "Smooth"}, "default": "snap", "order": 0},
		{"id": "vr.snap_angle", "category": "VR Movement", "label": "Snap angle", "type": "number", "default": 30.0, "min": 15.0, "max": 90.0, "step": 15.0, "unit": "degrees", "order": 1},
		{"id": "vr.smooth_turn_rate", "category": "VR Movement", "label": "Smooth turn speed", "type": "number", "default": 60.0, "min": 15.0, "max": 180.0, "step": 5.0, "unit": "degrees/s", "order": 2},
		{"id": "vr.move_speed", "category": "VR Movement", "label": "Movement speed", "type": "number", "default": 2.0, "min": 0.1, "max": 5.0, "step": 0.1, "unit": "m/s", "order": 3},
		{"id": "vr.move_dead_zone", "category": "VR Movement", "label": "Movement dead zone", "type": "number", "default": 0.1, "min": 0.05, "max": 0.5, "step": 0.05, "order": 4},
		{"id": "vr.turn_dead_zone", "category": "VR Movement", "label": "Turn release dead zone", "type": "number", "default": 0.3, "min": 0.1, "max": 0.6, "step": 0.05, "order": 5},
		{"id": "vr.comfort_vignette", "category": "VR Comfort", "label": "Movement vignette", "type": "boolean", "default": false, "order": 0},
		{"id": "vr.snap_blink", "category": "VR Comfort", "label": "Brief snap-turn blink", "type": "boolean", "default": false, "order": 1},
		{"id": "vr.seated_mode", "category": "VR Comfort", "label": "Seated mode (short collision capsule)", "type": "boolean", "default": false, "order": 2},
		{"id": "vr.jump_enabled", "category": "VR Movement", "label": "Allow right stick-click jump", "type": "boolean", "default": false, "order": 6},
		{"id": "input.xr_main_menu_action", "category": "Controls", "label": "VR main menu button", "type": "enum", "options": {"ax_button": "A/X (lower face button)", "menu_button": "Menu"}, "default": "ax_button", "order": 5},
		{"id": "cache.quota_mib", "category": "Assets", "label": "Cache storage budget", "description": "Active assets and imported originals are protected. A full cache rejects new downloads.", "type": "number", "default": 4096.0, "min": 256.0, "max": 65536.0, "step": 256.0, "unit": "MiB", "order": 0},
		{"id": "cache.automatic_refresh", "category": "Assets", "label": "Check cached assets for updates", "description": "Revalidate on use and periodically check loaded avatars. World updates never replace the active scene automatically.", "type": "boolean", "default": true, "order": 1},
		{"id": "cache.allow_http", "category": "Assets", "label": "Allow insecure HTTP asset URLs (development)", "description": "Off by default. HTTP traffic can be read or changed in transit.", "type": "boolean", "default": false, "order": 2},
		{"id": "cache.trust_remote_worlds", "category": "Assets", "label": "Trust remote world publishers (allows executable Godot content)", "description": "Off by default. World scenes are not sandboxed and may execute scripts. Enable only when every world URL you open comes from a publisher you trust.", "type": "boolean", "default": false, "order": 3},
		{"id": "audio.microphone_muted", "category": "Audio", "label": "Mute microphone", "description": "Stop recording and sending your microphone audio.", "type": "boolean", "default": true, "order": 0},
		{"id": "audio.master_volume", "category": "Audio", "label": "Master volume", "type": "number", "default": 80.0, "min": 0.0, "max": 100.0, "step": 1.0, "unit": "%", "order": 1},
		{"id": "audio.voice_volume", "category": "Audio", "label": "Other players' volume", "type": "number", "default": 100.0, "min": 0.0, "max": 100.0, "step": 1.0, "unit": "%", "order": 2},
		{"id": "input.toggle_microphone", "category": "Controls", "label": "Toggle microphone", "description": "Click to rebind. Escape cancels. Conflicting keys are rejected.", "type": "key_binding", "default": KEY_V, "order": 0},
		{"id": "input.toggle_animation_menu", "category": "Controls", "label": "Emote menu", "description": "Open the eight-slot emote wheel. Click to rebind; Escape cancels.", "type": "key_binding", "default": KEY_B, "order": 3},
		{"id": "input.xr_emote_action", "category": "Controls", "label": "VR emote wheel action", "description": "OpenXR boolean action used for hold-to-open controller interaction.", "type": "enum", "options": {"by_button": "B/Y button", "menu_button": "Menu button"}, "default": "by_button", "order": 4},
		{"id": "interface.emote_haptics", "category": "Interface", "label": "Emote wheel haptics", "type": "boolean", "default": true, "order": 1},
		{"id": "interface.emote_wheel_size", "category": "Interface", "label": "VR emote wheel diameter", "type": "number", "default": 0.42, "min": 0.25, "max": 0.7, "step": 0.01, "unit": "m", "order": 2},
		{"id": "interface.emote_dead_zone", "category": "Interface", "label": "Emote wheel center dead zone", "type": "number", "default": 0.28, "min": 0.2, "max": 0.45, "step": 0.01, "order": 3},
		{"id": "audio.microphone_gain", "category": "Audio", "label": "Microphone gain", "type": "number", "default": 1.0, "min": 0.0, "max": 2.0, "step": 0.05, "order": 3},
		{"id": "audio.voice_threshold", "category": "Audio", "label": "Voice activation threshold", "description": "Samples quieter than this are not sent.", "type": "number", "default": 0.004, "min": 0.0, "max": 0.1, "step": 0.001, "order": 4},
		{"id": "controls.mouse_sensitivity", "category": "Controls", "label": "Mouse sensitivity", "type": "number", "default": 0.003, "min": 0.0001, "max": 0.02, "step": 0.0001, "order": 1},
		{"id": "controls.invert_mouse_y", "category": "Controls", "label": "Invert mouse Y", "type": "boolean", "default": false, "order": 2},
		{"id": "interface.show_nameplates", "category": "Interface", "label": "Show player names", "type": "boolean", "default": true, "order": 0},
	]:
		register_setting(definition)
