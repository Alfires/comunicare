extends "res://suite.gd"

var canvas: SubViewport

func run():
	network = root.get_node("NetworkHandler")
	save = root.get_node("SaveData")
	alice = save.profile.get_local_fingerprint()
	bob_service = load("res://scripts/profile/profile_service.gd").new()
	bob_service.configure(Crypto.new().generate_rsa(2048), "res://unused-bob.cfg")
	bob_service.local["profile.username"] = "Bob"
	bob_service.local["profile.avatar_url"] = "https://avatars.example/bob.vrm"
	bob_service._sign(bob_service.local)
	bob = bob_service.get_local_fingerprint()
	install_legacy_membership()
	network._on_instance_snapshot(snapshot())
	# The desktop tiling compositor controls the top-level window dimensions.
	# Fixed-size GPU viewports test exact layouts independently of that policy;
	# their output is also displayed in the real desktop window.
	canvas = SubViewport.new()
	canvas.gui_embed_subwindows = true
	canvas.size = Vector2i(1000, 700)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var preview = TextureRect.new()
	preview.texture = canvas.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	var scene = load(MENU).instantiate()
	canvas.add_child(scene)
	var artifact_dir = OS.get_cmdline_user_args()[0]
	print("Display: ", DisplayServer.get_name(), "; renderer: ", RenderingServer.get_video_adapter_name())
	print("XR interfaces (enumeration only, no headset session): ", XRServer.get_interfaces())
	for dimensions in [Vector2i(1000, 700), Vector2i(640, 480)]:
		canvas.size = dimensions
		await settle()
		check(scene.size == Vector2(dimensions), "GPU viewport renders exact requested dimensions " + str(dimensions))
		check(scene.header.get_global_rect().end.y <= scene.player_list.get_global_rect().position.y,
			"rendered metadata is above player list at " + str(dimensions))
		check(scene.get_node("VBoxContainer/ScrollContainer").size.y >= 80,
			"rendered roster retains usable height at " + str(dimensions))
		for owner in [alice, bob]:
			var player_row = row(scene, owner)
			check(player_row.get_global_rect().end.x <= dimensions.x + 1,
				"player row including moderation buttons fits window at " + str(dimensions))
		button(scene, "Edit instance").pressed.emit()
		await settle()
		check(scene.save_button.get_global_rect().end.y <= dimensions.y,
			"metadata Save stays inside rendered window at " + str(dimensions))
		button(scene, "Cancel").pressed.emit()
		await settle()
		await screenshot(artifact_dir.path_join("active-%dx%d.png" % [dimensions.x, dimensions.y]))
	var previous_clipboard = DisplayServer.clipboard_get()
	button(scene, "Copy code").pressed.emit()
	check(DisplayServer.clipboard_get() == "A", "display-backed Copy writes acknowledged session code to real clipboard")
	DisplayServer.clipboard_set(previous_clipboard)
	var first = button(row(scene, bob), "Bob")
	first.grab_focus()
	check(first.has_focus(), "player profile button accepts keyboard focus")
	var move = InputEventAction.new()
	move.action = "ui_focus_next"
	move.pressed = true
	canvas.push_input(move)
	await settle()
	check(canvas.gui_get_focus_owner() != null and canvas.gui_get_focus_owner() != first,
		"keyboard focus can move from player name to next action")
	button(row(scene, bob), "Bob").pressed.emit()
	await settle()
	check(scene.profile_panel.is_visible_in_tree() and not scene.profile_panel.is_editable(),
		"rendered profile opens read-only for clicked remote user")
	await screenshot(artifact_dir.path_join("remote-profile.png"))
	scene.profile_panel._close()
	await settle()
	check(scene.get_node("VBoxContainer").is_visible_in_tree(), "rendered profile Back restores roster")
	button(row(scene, bob), "Ban").pressed.emit()
	await settle()
	check(scene.confirmation.visible and scene.confirmation.size.x <= canvas.size.x,
		"rendered ban confirmation fits window")
	await screenshot(artifact_dir.path_join("ban-confirmation.png"))
	scene.confirmation.hide()
	var long_profile = bob_service.local.duplicate(true)
	long_profile["profile.username"] = "Long participant name ".repeat(5)
	long_profile.revision += 1
	bob_service._sign(long_profile)
	long_profile.peer_id = 2
	save.profile.replace_remote_profiles("A", [long_profile])
	await settle()
	check(row(scene, bob).get_global_rect().end.x <= canvas.size.x + 1,
		"long participant name does not push moderation actions outside viewport")
	await screenshot(artifact_dir.path_join("long-player-name.png"))
	var crowded = snapshot(2)
	for i in 25:
		crowded.members.append({"fingerprint": "%064x" % (i + 1), "peer_id": i + 3, "role": "member"})
	network._on_instance_snapshot(crowded)
	await settle()
	var scroll: ScrollContainer = scene.get_node("VBoxContainer/ScrollContainer")
	check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "crowded rendered roster exposes vertical scrolling")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await settle()
	check(scroll.scroll_vertical > 0, "crowded roster can scroll to later players")
	await screenshot(artifact_dir.path_join("crowded-roster.png"))
	scene.free()
	print("\nDisplay acceptance: %d passed, %d failed" % [passed, failed])
	print("Screenshots: ", artifact_dir)
	quit(1 if failed else 0)

func settle():
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw

func screenshot(path: String):
	await RenderingServer.frame_post_draw
	check(canvas.get_texture().get_image().save_png(path) == OK, "rendered screenshot saved: " + path.get_file())
