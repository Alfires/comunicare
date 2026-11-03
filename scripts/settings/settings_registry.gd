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
		{"id": "cache.quota_mib", "category": "Assets", "label": "Cache storage budget", "description": "Active assets and imported originals are protected. A full cache rejects new downloads.", "type": "number", "default": 4096.0, "min": 256.0, "max": 65536.0, "step": 256.0, "unit": "MiB", "order": 0},
		{"id": "cache.automatic_refresh", "category": "Assets", "label": "Check cached assets for updates", "description": "Revalidate on use and periodically check loaded avatars. World updates never replace the active scene automatically.", "type": "boolean", "default": true, "order": 1},
		{"id": "cache.allow_http", "category": "Assets", "label": "Allow insecure HTTP asset URLs (development)", "description": "Off by default. HTTP traffic can be read or changed in transit.", "type": "boolean", "default": false, "order": 2},
		{"id": "audio.microphone_muted", "category": "Audio", "label": "Mute microphone", "description": "Stop recording and sending your microphone audio.", "type": "boolean", "default": true, "order": 0},
		{"id": "audio.master_volume", "category": "Audio", "label": "Master volume", "type": "number", "default": 80.0, "min": 0.0, "max": 100.0, "step": 1.0, "unit": "%", "order": 1},
		{"id": "audio.voice_volume", "category": "Audio", "label": "Other players' volume", "type": "number", "default": 100.0, "min": 0.0, "max": 100.0, "step": 1.0, "unit": "%", "order": 2},
		{"id": "input.toggle_microphone", "category": "Controls", "label": "Toggle microphone", "description": "Click to rebind. Escape cancels. Conflicting keys are rejected.", "type": "key_binding", "default": KEY_V, "order": 0},
		{"id": "audio.microphone_gain", "category": "Audio", "label": "Microphone gain", "type": "number", "default": 1.0, "min": 0.0, "max": 2.0, "step": 0.05, "order": 3},
		{"id": "audio.voice_threshold", "category": "Audio", "label": "Voice activation threshold", "description": "Samples quieter than this are not sent.", "type": "number", "default": 0.004, "min": 0.0, "max": 0.1, "step": 0.001, "order": 4},
		{"id": "controls.mouse_sensitivity", "category": "Controls", "label": "Mouse sensitivity", "type": "number", "default": 0.003, "min": 0.0001, "max": 0.02, "step": 0.0001, "order": 1},
		{"id": "controls.invert_mouse_y", "category": "Controls", "label": "Invert mouse Y", "type": "boolean", "default": false, "order": 2},
		{"id": "interface.show_nameplates", "category": "Interface", "label": "Show player names", "type": "boolean", "default": true, "order": 0},
	]:
		register_setting(definition)
