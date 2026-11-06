extends SceneTree
var passed := 0
var failed := 0
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ", title)
	if ok: passed += 1
	else: failed += 1
func run():
	var save = root.get_node("SaveData")
	save.load_acount()
	var loader = root.get_node("DataLoader")
	var browser = load("res://scenes/GUI/avatar_browser.tscn").instantiate()
	root.add_child(browser)
	root.size = Vector2i(1000, 800)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check(browser.has_node("BrowserLayout") and not browser.advanced_filters.visible, "browser starts with uncluttered named navigation and collapsed advanced filters")
	browser.search_box.text = "robot"
	var sources = browser.registry.sources.duplicate(true)
	browser.registry.sources.clear() # No implicit external requests in this suite.
	browser._search(false)
	check(browser.state.query == "robot", "Search uses current typed query even without Enter")
	browser.registry.sources = sources
	browser.transport_options = {"allow_loopback_http": true}
	var record = {"provider": "osa", "id": "fixture", "title": "Fixture avatar", "type": "avatar", "format": "vrm", "license": "CC0-1.0", "redistribution": true,
		"download_url": OS.get_environment("COMUNICARE_AVATAR_TEST_URL")}
	browser._clear()
	browser._card(record)
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	var card = browser.card_buttons["osa:fixture"]
	var point = root.get_final_transform() * card.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed in [true, false]:
		var click = InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await process_frame
	check(browser.selected_record.get("id") == "fixture", "pointer click on result card selects avatar")
	if browser.selected_record.is_empty():
		browser.queue_free()
		await process_frame
		quit(1)
		return
	await process_frame
	check(browser.detail.is_visible_in_tree() and browser.detail.use_button.is_visible_in_tree(),
		"selecting result reveals detail and Use this avatar through hidden scroll parent")
	var preview_deadline = Time.get_ticks_msec() + 30000
	while not is_instance_valid(browser.preview.model) and Time.get_ticks_msec() < preview_deadline:
		await create_timer(0.01).timeout
	check(is_instance_valid(browser.preview.model), "selecting avatar card automatically loads its independent preview")
	browser.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	browser.size = Vector2(640, 480)
	browser._layout()
	await process_frame
	await process_frame
	check(browser.detail.get_global_rect().end.x <= browser.get_global_rect().end.x + 1,
		"compact selection detail fits browser instead of pushing Apply offscreen")
	await browser._preview_record(record)
	check(browser.preview != null and is_instance_valid(browser.preview.model), "catalog avatar loads in production browser preview: " + browser.status.text)
	check(loader.get_avatar_configuration().model.is_empty(), "preview never equips model")
	var use = browser.detail.use_button
	var use_point = root.get_final_transform() * use.get_global_rect().get_center()
	var use_motion = InputEventMouseMotion.new()
	use_motion.position = use_point
	Input.parse_input_event(use_motion)
	await process_frame
	for pressed in [true, false]:
		var click = InputEventMouseButton.new()
		click.position = use_point
		click.global_position = use_point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await process_frame
	var deadline = Time.get_ticks_msec() + 30000
	while (browser.applying_avatar or loader.get_avatar_configuration().model.is_empty()) and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(not loader.get_avatar_configuration().model.is_empty() and browser.loading_bar.value == 100 and not browser.editor_open,
		"single Apply action validates and equips avatar with completed inline progress, no modal and no editor")
	check(browser.find_children("*", "AcceptDialog", true, false).all(func(dialog): return not dialog.visible), "Apply never opens a modal dialog")
	await process_frame
	var wrong = record.duplicate(true)
	wrong.sha256 = "f".repeat(64)
	var applied_before = loader.get_avatar_configuration().model.duplicate(true)
	await browser._apply_avatar(wrong)
	check(browser.loading_bar.value < 100 and not browser.applying_avatar and "digest" in browser.loading_label.text.to_lower()
		and loader.get_avatar_configuration().model == applied_before, "failed one-click Apply releases busy state and preserves equipped avatar")
	await process_frame
	var removed = record.duplicate(true)
	removed.provider = "removed-provider"
	await browser._apply_avatar(removed)
	check(not browser.applying_avatar and "provider" in browser.loading_label.text.to_lower(), "removed provider returns actionable Apply failure instead of crashing")
	await process_frame
	await browser._preview_record(wrong)
	check("digest" in browser.status.text.to_lower(), "preview rejects mismatched catalog digest just like import")
	await browser._import_record(record)
	check(browser.editor_open, "catalog avatar opens validated source draft: " + browser.status.text)
	if browser.editor_open:
		var editor
		for child in browser.get_children():
			if child.get_script() == load("res://scripts/GUI/animation_menue.gd"): editor = child
		await process_frame
		check(editor != null and editor.size.x > 100 and editor.size.y > 100, "review editor has visible usable dimensions")
		if editor != null:
			await editor.apply()
			check(not loader.get_avatar_configuration().model.is_empty(), "Apply equips validated browser avatar: " + editor.status.text)
			var model = await loader.get_avatar_configuration().load_model("")
			check(model != null, "applied browser avatar loads from pinned cache for player")
			if model != null: model.free()
			var configuration = loader.get_avatar_configuration()
			var previous = configuration.model.duplicate(true)
			var missing = previous.duplicate(true)
			missing.hash = "e".repeat(64)
			configuration.last_error = ""
			check(not await configuration.apply(missing, []) and not configuration.last_error.is_empty() and configuration.model == previous,
				"missing cached avatar gives actionable Apply error without replacing current avatar")
			configuration.last_error = ""
			check(not await configuration.apply(previous, [{"hash": "bad"}]) and not configuration.last_error.is_empty(),
				"invalid animation source returns nonempty Apply error")
	browser.queue_free()
	await process_frame
	check(save.use_temporary_identity(), "duplicate-window temporary identity can be configured")
	var temporary = loader.get_avatar_configuration()
	check(temporary.memory_only and temporary.writable and temporary.path.is_empty(), "temporary window supports avatar selection without durable account configuration")
	var source = await temporary.import_source("res://browser-avatar.vrm", true, true)
	check(not source.is_empty() and await temporary.apply(source, []), "temporary window can import and Apply avatar in memory")
	check(not FileAccess.file_exists("user://avatars/" + save.profile.get_local_fingerprint() + ".json"), "temporary avatar selection never creates account configuration on disk")
	if loader.avatar_configuration != null:
		loader.avatar_configuration.free()
		loader.avatar_configuration = null
	await process_frame
	print("Avatar browser acceptance: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)
