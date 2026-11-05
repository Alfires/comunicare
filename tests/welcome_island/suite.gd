extends SceneTree

var passed := 0
var failed := 0

func _initialize(): call_deferred("run")

func check(ok: bool, title: String):
	if ok: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func frames(count: int = 6):
	for index in count: await process_frame

func click_menu(player: Node):
	var button = player.get_node("MenuProbe")
	var point = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event)
		await process_frame
	check(player.clicks > 0, "offline menu probe receives hit-tested pointer input")

func run():
	root.size = Vector2i(800, 600)
	var group = OS.get_environment("WELCOME_SUITE")
	var save = root.get_node("SaveData")
	var network = root.get_node("NetworkHandler")
	check(not FileAccess.file_exists(save.key_path), "isolated process starts without an account key")
	check(not DirAccess.dir_exists_absolute("user://asset_cache"), "cold start has no downloaded asset cache")
	check(save.voice.is_muted(), "settings/mute initialized before mounting a player")
	if group == "account":
		var file = FileAccess.open(save.key_path, FileAccess.WRITE)
		file.store_string("preserve this corrupt fixture key")
		file.close()
	else:
		# Valid local fixture avoids key generation cost while exercising real load.
		Crypto.new().generate_rsa(2048).save(save.key_path)
	var before = FileAccess.get_sha256(save.key_path)
	if group == "xr":
		var startup = load("res://fixtures/xr_startup.gd").new()
		root.add_child(startup)
	else:
		change_scene_to_file("res://scenes/startup.tscn")
	await frames()
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/world.tscn",
		"real startup loads bundled home without downloaded assets")
	var players = get_nodes_in_group("player")
	check(players.size() == 1, "startup mounts exactly one local player")
	if players.is_empty():
		finish(); return
	var player = players[0]
	check(player.get_parent() == root, "local player lives at scene-tree root")
	check(player.name == ("player_vr" if group == "xr" else "player_desktop"),
		"startup selects the requested desktop or synthetic XR player")
	check(FileAccess.get_sha256(save.key_path) == before, "startup preserves existing key bytes")
	check(save.voice.is_muted(), "startup does not enable microphone")
	if group == "account":
		check(not save.account_error.is_empty(), "corrupt account reports a recovery error")
		check(network.started == 0, "corrupt account never authenticates with relay")
		check(not DirAccess.dir_exists_absolute("user://profiles"), "corrupt account never creates a replacement profile")
	else:
		check(network.started == 1 and network.pending, "home ready while network completion is still blocked")
	await click_menu(player)
	if group != "account":
		network.completed.emit()
		await frames()
		check(network.failed and not network.pending, "controlled failed connection completes independently")
		check(is_instance_valid(player) and player.get_parent() == root, "failed relay does not remove player")
	# Re-enter startup, not just the home scene: it must reuse the persistent player.
	for index in 3:
		change_scene_to_file("res://scenes/startup.tscn")
		await frames()
		check(get_nodes_in_group("player").size() == 1, "repeated startup keeps exactly one player (%s)" % index)
		check(is_instance_valid(player) and player.get_parent() == root, "repeated home entry preserves original player (%s)" % index)
	check(FileAccess.get_sha256(save.key_path) == before, "repeated entry preserves account key")
	check(network.started == (0 if group == "account" else 1), "repeated startup does not restart relay setup")
	check(save.voice.capture_node == null, "isolated startup never mounts physical capture")
	if group != "account":
		check(save.account_error.is_empty(), "repeated startup does not reload or damage the loaded account")
	if OS.get_environment("WELCOME_RENDERED") == "1":
		await RenderingServer.frame_post_draw
		var image = root.get_texture().get_image()
		var path = "/tmp/opencode/welcome-foundation-desktop.png"
		check(image != null and not image.is_empty() and image.save_png(path) == OK, "rendered home/menu screenshot saved: " + path)
	for local in get_nodes_in_group("player"): local.queue_free()
	if current_scene != null: current_scene.queue_free()
	await frames(2)
	finish()

func finish():
	print("Welcome foundation: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)
