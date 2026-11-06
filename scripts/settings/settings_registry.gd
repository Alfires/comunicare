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
				and (value not in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META] or value in definition.get("allowed_modifier_keys", [])) \
				and not OS.get_keycode_string(value).is_empty()
	return false

func register_defaults():
	for definition in [
		{"id": "assets.avatar_warning_mib", "category": "Assets", "label": "Large avatar warning", "description": "Ask before importing or previewing an avatar above this file size. Effective threshold never exceeds the avatar size limit.", "type": "number", "default": 256.0, "min": 32.0, "max": 1024.0, "step": 32.0, "unit": "MiB", "order": 10},
		{"id": "assets.avatar_limit_mib", "category": "Assets", "label": "Maximum avatar file size", "description": "Hard import/loading limit. Large files can require substantially more RAM/VRAM. Maximum supported file size is 1 GiB.", "type": "number", "default": 1024.0, "min": 64.0, "max": 1024.0, "step": 32.0, "unit": "MiB", "order": 11},
		{"id": "interface.theme_preset", "category": "Interface", "label": "Color scheme", "type": "enum", "options": {"graphite": "Graphite", "paper": "Paper", "forest": "Forest", "sand": "Sand", "night": "Night", "high_contrast": "High contrast"}, "default": "graphite", "order": -4},
		{"id": "interface.accent", "category": "Interface", "label": "Accent color", "type": "enum", "options": {"teal": "Teal", "blue": "Blue", "amber": "Amber", "green": "Green", "rose": "Rose", "violet": "Violet", "match_highlight": "Match 3D highlight"}, "default": "teal", "order": -3},
		{"id": "interface.roundness", "category": "Interface", "label": "Corner roundness", "description": "How rounded buttons, panels and the tablet frame are.", "type": "enum", "options": {"square": "Square", "subtle": "Subtle", "rounded": "Rounded", "round": "Round"}, "default": "subtle", "order": -2.5},
		{"id": "interface.ui_scale", "category": "Interface", "label": "Interface size", "description": "Scales menus on desktop and the VR tablet.", "type": "number", "default": 1.0, "min": 0.75, "max": 1.5, "step": 0.05, "unit": "×", "order": -2},
		{"id": "interface.reduce_motion", "category": "Interface", "label": "Reduce motion", "description": "Turns off easing for the tablet, menus and avatar preview.", "type": "boolean", "default": false, "order": -1},
		{"id": "vr.menu_pin_mode", "category": "VR Menu", "label": "Tablet placement", "description": "Follow my view brings the tablet back when you turn away.", "type": "enum", "options": {"pinned": "Stay where I put it", "follow": "Follow my view"}, "default": "pinned", "order": 0},
		{"id": "vr.menu_scale", "category": "VR Menu", "label": "Tablet size", "type": "number", "default": 1.0, "min": 0.6, "max": 1.6, "step": 0.05, "unit": "×", "order": 1},
		{"id": "vr.menu_direct_touch", "category": "VR Menu", "label": "Touch the tablet with the controller tip", "description": "Press buttons by touching the screen instead of pointing.", "type": "boolean", "default": false, "order": 2},
		{"id": "vr.menu_hand", "category": "VR Menu", "label": "Tablet side", "type": "enum", "options": {"left": "Left", "right": "Right", "either": "Centered"}, "default": "either", "order": 3},
		{"id": "interface.hover_color", "category": "Interface", "label": "Selectable item highlight color", "type": "enum", "options": {"cyan": "Cyan", "yellow": "Yellow", "green": "Green", "magenta": "Magenta", "white": "White"}, "default": "cyan", "order": 8},
		{"id": "interface.mirror_quality", "category": "Interface", "label": "Mirror reflection quality", "description": "Local mirror resolution: Low 384px, Medium 768px, High 1536px on the longest edge. Higher quality uses more GPU time.", "type": "enum", "options": {"low": "Low", "medium": "Medium", "high": "High"}, "default": "medium", "order": 5},
		{"id": "interface.mirror_width", "category": "Interface", "label": "Mirror width (X)", "type": "number", "default": 1.0, "min": 0.4, "max": 3.0, "step": 0.1, "unit": "m", "order": 6},
		{"id": "interface.mirror_height", "category": "Interface", "label": "Mirror height (Y)", "type": "number", "default": 1.5, "min": 0.6, "max": 4.5, "step": 0.1, "unit": "m", "order": 7},
		{"id": "input.sprint", "category": "Controls", "label": "Sprint (hold)", "description": "Hold while moving to travel 1.5 times faster. VR: hold left joystick click.", "type": "key_binding", "allowed_modifier_keys": [KEY_CTRL], "default": KEY_CTRL, "order": 9},
		{"id": "network.lan_discovery", "category": "Network", "label": "Discover relays on local network", "description": "Receive local multicast hints. Only explicitly certificate-trusted directories are queried; advertisements never log in or change your saved relay order. Changes take effect after restart.", "type": "boolean", "default": true, "order": 2},
		{"id": "network.relay_address", "category": "Network", "label": "Legacy relay address (migration only)", "visible": false, "type": "text", "default": "127.0.0.1", "min_length": 1, "max_length": 253, "order": 0},
		{"id": "network.relay_port", "category": "Network", "label": "Legacy relay UDP port (migration only)", "visible": false, "type": "number", "default": 7374.0, "min": 1.0, "max": 65535.0, "step": 1.0, "order": 1},
		{"id": "input.world_grab", "category": "Controls", "label": "Pick up / drop world item", "type": "key_binding", "action": "world_grab", "default": KEY_E, "order": 8},
		{"id": "vr.share_tracking", "category": "VR Comfort", "label": "Share live head/hand/body tracking in this instance", "description": "Sends bounded avatar-relative poses, never room meshes or tracker identifiers.", "type": "boolean", "default": true, "order": 4},
		{"id": "vr.locomotion_mode", "category": "VR Movement", "label": "Locomotion", "type": "enum", "options": {"smooth": "Smooth", "teleport": "Point and teleport"}, "default": "smooth", "order": -1},
		{"id": "vr.head_clip_fade", "category": "VR Comfort", "label": "Fade when head intersects world geometry", "type": "boolean", "default": true, "order": 3},
		{"id": "vr.turn_mode", "category": "VR Movement", "label": "Turning", "type": "enum", "options": {"snap": "Snap", "smooth": "Smooth"}, "default": "snap", "order": 0},
		{"id": "vr.snap_angle", "category": "VR Movement", "label": "Snap angle", "type": "number", "default": 30.0, "min": 15.0, "max": 90.0, "step": 15.0, "unit": "degrees", "order": 1},
		{"id": "vr.smooth_turn_rate", "category": "VR Movement", "label": "Smooth turn speed", "type": "number", "default": 60.0, "min": 15.0, "max": 180.0, "step": 5.0, "unit": "degrees/s", "order": 2},
		{"id": "vr.move_speed", "category": "VR Movement", "label": "Base movement speed (PC and VR)", "description": "Walking uses twice this base value on desktop and full-stick VR (default: 4 m/s). Sprint is 1.5 times walking speed (default: 6 m/s). Partial VR stick input remains slower.", "type": "number", "default": 2.0, "min": 0.1, "max": 5.0, "step": 0.1, "unit": "m/s base", "order": 3},
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
		{"id": "cache.trust_remote_worlds", "category": "Assets", "label": "Legacy world trust preference (no longer grants code execution)", "description": "Kept for settings compatibility only. Remote worlds must use the validated safe format; enabling this never allows native scripts or addons from a world.", "type": "boolean", "default": false, "order": 3},
		{"id": "world.scripts_enabled", "category": "Assets", "label": "Run restricted world visual scripts", "description": "Disable to stop current world callbacks immediately. Re-enable takes effect on the next world load. Never grants native Godot script access.", "type": "boolean", "default": true, "order": 4},
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
