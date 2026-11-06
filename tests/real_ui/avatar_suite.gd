extends SceneTree
var passed := 0
var failed := 0
var pending_applies := 0

func apply_in_background(browser, record):
	pending_applies += 1
	await browser._apply_avatar(record)
	pending_applies -= 1
func _initialize(): call_deferred("run")
func check(ok: bool, title: String):
	print("PASS: " if ok else "FAIL: ", title)
	if ok: passed += 1
	else: failed += 1
func run():
	var save = root.get_node("SaveData")
	save.load_acount()
	var loader = root.get_node("DataLoader")
	var compatibility_id = "assets.avatar_compatibility_check"
	check(save.registry.get_definition(compatibility_id).get("default") == true, "avatar compatibility check is enabled by default and registered in settings")
	if not save.registry.get_definition(compatibility_id).is_empty():
		var configuration = loader.get_avatar_configuration()
		# Keep the real fixture's valid geometry/UVs, removing only humanoid
		# declarations to isolate compatibility policy from renderer import issues.
		var fixture = FileAccess.get_file_as_bytes("res://browser-avatar.vrm")
		var json_length = fixture.decode_u32(12)
		var document: Dictionary = JSON.parse_string(fixture.slice(20, 20 + json_length).get_string_from_utf8())
		var extensions: Dictionary = document.get("extensions", {})
		extensions.erase("VRM")
		extensions.erase("VRMC_vrm")
		for field in ["extensionsUsed", "extensionsRequired"]:
			if document.has(field): document[field] = document[field].filter(func(value): return value not in ["VRM", "VRMC_vrm"])
		var json_bytes = JSON.stringify(document).to_utf8_buffer()
		while json_bytes.size() % 4: json_bytes.append(32)
		var remaining = fixture.slice(20 + json_length)
		var unrigged = PackedByteArray()
		unrigged.resize(20)
		unrigged.encode_u32(0, 0x46546c67)
		unrigged.encode_u32(4, 2)
		unrigged.encode_u32(8, 20 + json_bytes.size() + remaining.size())
		unrigged.encode_u32(12, json_bytes.size())
		unrigged.encode_u32(16, 0x4e4f534a)
		unrigged.append_array(json_bytes)
		unrigged.append_array(remaining)
		var unrigged_path = "user://unrigged.glb"
		var unrigged_file = FileAccess.open(unrigged_path, FileAccess.WRITE)
		unrigged_file.store_buffer(unrigged)
		unrigged_file.close()
		save.store.set_value(compatibility_id, true)
		check(not await configuration._validate_model(unrigged_path), "strict mode rejects a model without declared humanoid mapping")
		save.store.set_value(compatibility_id, false)
		check(await configuration._validate_model(unrigged_path), "disabled compatibility check accepts valid self-contained GLB without humanoid mapping")
		var malformed = FileAccess.open("user://malformed.glb", FileAccess.WRITE)
		malformed.store_string("not a model")
		malformed.close()
		check(not await configuration._validate_model("user://malformed.glb"), "disabling compatibility check never accepts malformed model bytes")
		save.store.set_value(compatibility_id, true)
	var fixture_bytes = FileAccess.get_file_as_bytes("res://browser-avatar.vrm")
	var policy = load("res://scripts/assets/avatar_size_policy.gd")
	check(policy.classify(fixture_bytes.size(), save.store) == "allow", "actual avatar fixture byte count is below configured warning and hard limits")
	print("AVATAR_BYTES: ", fixture_bytes.size(), " LIMIT_BYTES: ", policy.limits(save.store).hard)
	var local_player = load("res://scenes/player/player_desktop.tscn").instantiate()
	root.add_child(local_player)
	local_player.set_physics_process(false)
	local_player.set_process(false)
	var vr_player = load("res://scenes/player/player_vr.tscn").instantiate()
	root.add_child(vr_player)
	vr_player.set_physics_process(false)
	vr_player.set_process(false)
	root.size = Vector2i(1000, 800)
	var overlay = load("res://scenes/GUI/desktop_overlay.tscn").instantiate()
	root.add_child(overlay)
	overlay.open()
	overlay.shell.open_page("avatars")
	var browser = overlay.shell.page("avatars")
	await process_frame
	await process_frame
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
	var second = record.duplicate(true)
	second.id = "latest-selection"
	apply_in_background(browser, record)
	browser._details(second)
	var cancel_deadline = Time.get_ticks_msec() + 5000
	while pending_applies > 0 and Time.get_ticks_msec() < cancel_deadline: await create_timer(0.01).timeout
	check(pending_applies == 0 and browser.detail.status_label.text.is_empty() and not browser.detail.use_button.disabled,
		"canceled Apply cannot replace newly selected card status or block its Use button")
	browser._details(record)
	browser._details(second)
	await process_frame
	await process_frame
	check(browser.selected_record.id == second.id, "rapid result selections cannot let deferred preview reselect an older avatar")
	browser._restore_results()
	await process_frame
	await process_frame
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
	if DisplayServer.get_name() != "headless" and is_instance_valid(browser.preview.model):
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var shown = browser.preview.viewport.get_texture().get_image()
		shown.save_png("user://avatar-preview-visible.png")
		browser.preview.model.hide()
		browser.preview.stage._dirty = true
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var hidden = browser.preview.viewport.get_texture().get_image()
		check(shown.get_data() != hidden.get_data(), "rendered preview pixels contain avatar geometry, not only an allocated model node")
		browser.preview.model.show()
		browser.preview.stage._dirty = true
	root.size = Vector2i(640, 480)
	overlay.apply_layout(Vector2(640, 480))
	browser._layout()
	await process_frame
	await process_frame
	check(browser.detail.get_global_rect().end.x <= browser.get_global_rect().end.x + 1,
		"compact selection detail fits browser instead of pushing Apply offscreen")
	# A width change may run deferred layout/preview work. Wait for the current
	# selection rather than launching a competing second preview request.
	var resized_preview_deadline = Time.get_ticks_msec() + 30000
	while not is_instance_valid(browser.preview.model) and Time.get_ticks_msec() < resized_preview_deadline:
		await create_timer(0.01).timeout
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
	var player_deadline = Time.get_ticks_msec() + 15000
	while (not is_instance_valid(local_player.avatar_model) or local_player.avatar_model.get_meta("asset_revision", "") != loader.get_avatar_configuration().model.get("hash")) and Time.get_ticks_msec() < player_deadline:
		await create_timer(0.01).timeout
	check(is_instance_valid(local_player.avatar_model) and local_player.avatar_model.get_meta("asset_revision", "") == loader.get_avatar_configuration().model.get("hash"),
		"Use button replaces actual production desktop player model, not only saved configuration")
	var vr_deadline = Time.get_ticks_msec() + 15000
	while (not is_instance_valid(vr_player.vrm_model) or vr_player.vrm_model.get_meta("asset_revision", "") != loader.get_avatar_configuration().model.get("hash")) and Time.get_ticks_msec() < vr_deadline:
		await create_timer(0.01).timeout
	check(is_instance_valid(vr_player.vrm_model) and vr_player.vrm_model.get_meta("asset_revision", "") == loader.get_avatar_configuration().model.get("hash"), "Use button replaces production VR player model without requiring active headset")
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
			editor.queue_free()
			await process_frame
	var local_editor = load("res://scenes/GUI/animation_menue.tscn").instantiate()
	await loader.get_avatar_configuration().apply({}, [])
	browser.add_child(local_editor)
	check(not local_editor.permission.button_pressed, "local import defaults to no redistribution consent")
	local_editor.choose_model_file()
	local_editor.picker.hide()
	# Exercise the actual FileDialog signal wiring, not direct import_source.
	local_editor.picker.file_selected.emit(ProjectSettings.globalize_path("res://browser-avatar.vrm"))
	var local_deadline = Time.get_ticks_msec() + 30000
	while local_editor.busy and Time.get_ticks_msec() < local_deadline: await create_timer(0.01).timeout
	check(not local_editor.draft_model.is_empty(), "real local file-picker signal imports a validated avatar draft: " + local_editor.status.text)
	await process_frame
	await process_frame
	var local_scroll = local_editor.apply_button.get_parent().get_parent() as ScrollContainer
	local_scroll.ensure_control_visible(local_editor.apply_button)
	await process_frame
	var local_point = root.get_final_transform() * local_editor.apply_button.get_global_rect().get_center()
	for pressed in [true, false]:
		var click = InputEventMouseButton.new()
		click.position = local_point
		click.global_position = local_point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await process_frame
	while local_editor.busy and Time.get_ticks_msec() < local_deadline: await create_timer(0.01).timeout
	check(local_editor.status.text.begins_with("Applied."), "local editor Apply button equips imported file: " + local_editor.status.text)
	check(not loader.get_avatar_configuration().model.get("share", true), "local equip never silently grants permission to share model bytes")
	var local_equip_deadline = Time.get_ticks_msec() + 15000
	var local_hash = local_editor.draft_model.get("hash", "")
	while (not is_instance_valid(local_player.avatar_model) or local_player.avatar_model.get_meta("asset_revision", "") != local_hash or not is_instance_valid(vr_player.vrm_model) or vr_player.vrm_model.get_meta("asset_revision", "") != local_hash) and Time.get_ticks_msec() < local_equip_deadline:
		await create_timer(0.01).timeout
	check(not local_hash.is_empty() and is_instance_valid(local_player.avatar_model) and local_player.avatar_model.get_meta("asset_revision", "") == local_hash and is_instance_valid(vr_player.vrm_model) and vr_player.vrm_model.get_meta("asset_revision", "") == local_hash, "private local Apply replaces both real player models after clearing previous selection")
	local_editor.queue_free()
	browser.queue_free()
	overlay.queue_free()
	local_player.queue_free()
	vr_player.queue_free()
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
