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
	browser._details(record)
	await browser._preview_record(record)
	check(browser.preview != null and is_instance_valid(browser.preview.model), "catalog avatar loads in production browser preview: " + browser.status.text)
	check(loader.get_avatar_configuration().model.is_empty(), "preview never equips model")
	var wrong = record.duplicate(true)
	wrong.sha256 = "f".repeat(64)
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
