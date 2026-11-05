extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)
func run():
	root.size = Vector2i(1000, 700)
	var save = root.get_node("SaveData")
	var before = FileAccess.get_sha256(save.store.config_path)
	var muted = save.voice.is_muted()
	var menu = load("res://scenes/GUI/settings_menue.tscn").instantiate()
	root.add_child(menu); await process_frame
	var pages = menu.find_children("*", "VBoxContainer", true, false).filter(func(node): return node.has_method("refresh_help"))
	check(pages.size() == 1, "Settings Controls provides an opt-in Help component")
	if not pages.is_empty():
		var help = pages[0]
		check(not help.details.visible, "extended help hidden on arrival")
		help.toggle.pressed.emit()
		check(help.details.visible, "explicit menu action reveals help")
		check(help.details.text.contains(OS.get_keycode_string(int(save.store.get_value("input.world_grab")))), "pickup help reads current binding")
		# Temporary live remap without saving: store ownership remains untouched.
		var definition = save.registry.definitions["input.world_grab"]
		var original = definition.default
		definition.default = KEY_G
		# Unset override uses registry default, as on a fresh profile.
		var defaults = preload("res://scripts/settings/settings_store.gd").new()
		defaults.configure(save.registry, "res://unused-help.cfg")
		help.refresh_help(defaults)
		check(help.details.text.contains("G — Pick up / drop"), "Help reflects remapped live controls rather than baked keys")
		definition.default = original; defaults.free()
		help.refresh_help()
		var hint_toggle = help.find_children("*", "CheckButton", true, false)[0]
		hint_toggle.button_pressed = false
		check(not root.get_meta("home_action_hints", true), "contextual highlights can be hidden without changing gameplay state")
		hint_toggle.button_pressed = true
		check(help.details.text.contains("Offline") and help.details.text.contains("local-only"), "help explains offline and local-only limits")
		check(help.details.text.contains("teleport") and help.details.text.contains("grip"), "help includes supported VR mode and grip explanation")
		help.toggle.pressed.emit()
		check(not help.details.visible, "Help can be hidden again")
		menu._render(); await process_frame
		pages = menu.find_children("*", "VBoxContainer", true, false).filter(func(node): return node.has_method("refresh_help"))
		check(not pages[0].details.visible, "rerender retains hidden help preference")
		check(FileAccess.get_sha256(save.store.config_path) == before, "show/hide/help navigation never saves preferences")
		check(save.voice.is_muted() == muted, "Help never enables microphone")
		check(root.get_node("NetworkHandler").current_session_id.is_empty(), "Help never joins or creates a session")
		if OS.get_environment("WELCOME_CREDITS_RENDERED") == "1":
			menu.select_category("Controls"); pages[0].toggle.pressed.emit()
			await process_frame; await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/opencode/island-help.png") == OK, "rendered Help captured")
	menu.queue_free(); await process_frame; await process_frame
	print("Welcome credits: %s passed, %s failed (Help)" % [passed, failed]); quit(1 if failed else 0)
