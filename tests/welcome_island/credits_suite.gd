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
	var menu = load("res://scenes/GUI/settings_menue.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check(menu.category_pages.has("Credits"), "Settings has dedicated Credits navigation")
	if menu.category_pages.has("Credits"):
		menu.select_category("Credits")
		var page = menu.category_pages.Credits
		var first_buttons = page.find_children("*", "Button", true, false).size()
		check(first_buttons > 0 and first_buttons <= 8, "Credits shows its first entries immediately and builds the rest progressively")
		for i in 30:
			if not page.is_processing(): break
			await process_frame
		check(not page.is_processing(), "progressive Credits build finishes within a few frames")
		check(page.has_method("load_entries"), "Credits has testable local manifest loader")
		var expected_ids: Array = []
		for manifest_path in ["res://assets/credits.json", "res://assets/welcome_island/manifest.json"]:
			var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			for record in manifest.assets: expected_ids.append(record.id)
		check(page.entries.map(func(entry): return entry.id) == expected_ids,
			"Credits exactly covers every bundled manifest entry including later additions")
		for entry in page.entries:
			check(not entry.title.is_empty() and not entry.author.is_empty() and not entry.terms.is_empty(), "asset author/title/full terms available offline: " + entry.id)
		check(page.find_children("*", "HTTPRequest", true, false).is_empty(), "Credits creates no HTTP requester")
		var buttons = page.find_children("*", "Button", true, false)
		check(buttons.all(func(b): return not b.text.contains("Reset")), "Credits contains no reset actions")
		var license_buttons = buttons.filter(func(b): return b.text == "Show full license text")
		check(license_buttons.size() == expected_ids.size(), "each entry exposes full license locally")
		license_buttons[0].grab_focus()
		check(license_buttons[0].has_focus(), "license control supports keyboard focus")
		license_buttons[0].pressed.emit()
		check(license_buttons[0].text == "Hide full license text", "explicit license action expands terms")
		license_buttons[0].pressed.emit()
		check(license_buttons[0].text == "Show full license text", "license text collapses without losing inventory")
		# Prevent the production explicit-link handler opening a real browser.
		for connection in page.source_requested.get_connections():
			page.source_requested.disconnect(connection.callable)
		page.set_meta("requests", 0)
		page.source_requested.connect(func(_url): page.set_meta("requests", page.get_meta("requests") + 1))
		check(page.get_meta("requests") == 0, "rendering never activates an external source")
		var source = buttons.filter(func(b): return b.text == "Open source website")
		check(not source.is_empty(), "external sources require explicit buttons")
		if not source.is_empty(): source[0].pressed.emit()
		check(page.get_meta("requests") == 1, "explicit source activation emits one request")
		var missing = page.entries[0].duplicate()
		missing.license_file = "assets/missing-license.txt"
		page.load_entries([null, {}, missing])
		check(page.entries.is_empty() and not page.error_text.is_empty(), "invalid records/missing licenses fail visibly without crashing")
		page.load_entries([])
		check(page.entries.is_empty(), "empty local inventory handled")
		var attributed = missing.duplicate()
		attributed.license_file = "assets/animations/CC0-1.0.txt"
		attributed.license = "CC-BY-4.0"
		attributed.attribution = "Required fixture acknowledgement"
		attributed.modifications = "Modified fixture notice"
		page.load_entries([attributed])
		check(page.entries.size() == 1 and page.find_children("*", "Label", true, false).any(func(label): return label.text.contains(attributed.attribution)),
			"mandatory attribution is displayed, not just stored")
		menu._render()
		check(menu.selected_category == "Credits" and menu.category_pages.Credits.visible, "rerender preserves Credits selection")
		await process_frame
		await process_frame
		var scroll = menu.get_node("Layout/Content/ScrollContainer")
		check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "long notices scroll within settings")
		# Same Control page inside the VR menu's viewport-sized canvas; no headset.
		root.size = Vector2i(800, 600)
		await process_frame
		check(menu.category_buttons.Credits.custom_minimum_size.y >= 44, "Credits navigation retains pointer-sized target")
		check(FileAccess.get_sha256(save.store.config_path) == before, "Credits navigation/rerender never writes settings")
		if OS.get_environment("WELCOME_CREDITS_RENDERED") == "1":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("/tmp/opencode/welcome-credits.png") == OK, "rendered Credits inspection saved")
	menu.queue_free()
	await process_frame
	await process_frame
	print("Welcome credits: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)
