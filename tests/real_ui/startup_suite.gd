extends SceneTree
## Actual startup/player/menu with production autoloads and isolated user data.
var passed := 0
var failed := 0
var shell: PackedScene

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func run():
	var save = root.get_node("SaveData")
	root.get_node("DataLoader").get_asset_cache().enabled = false
	# Preprovision a disposable key but let normal startup load it exactly once.
	var key = Crypto.new().generate_rsa(2048)
	key.save(save.key_path)
	# Avoid external avatar/capture work; production players/controls remain intact.
	save.data.avatar_url = ""
	save.data.default_avatar = ""
	var node = Node3D.new()
	node.name = "OfflineStartupShell"
	shell = PackedScene.new()
	shell.pack(node)
	node.free()
	shell.take_over_path("res://scenes/world.tscn")
	var network = root.get_node("NetworkHandler")
	var prefs = network.get_relay_preferences()
	for entry in prefs.snapshot().entries: prefs.remove_entry(entry.entry_id)
	var reservation = ENetConnection.new()
	reservation.create_host_bound("127.0.0.1", 0)
	var port = reservation.get_local_port()
	reservation.destroy()
	prefs.add_entry({"entry_id": "absent", "label": "Absent fixture", "host": "127.0.0.1", "port": port, "relay_id": ""})
	change_scene_to_file("res://scenes/startup.tscn")
	await create_timer(2.0).timeout
	check(not get_nodes_in_group("player").is_empty(), "production startup mounts local player before absent relay times out")
	check(current_scene != null and current_scene.name == "OfflineStartupShell", "production startup enters usable offline world while connecting")
	var players = get_nodes_in_group("player")
	if not players.is_empty(): check(players[0].get_node_or_null("menue") != null, "offline startup includes the real shared menu")
	check(network.has_method("cancel_relay_connection"), "trusted UI can cancel slow relay selection")
	if network.has_method("cancel_relay_connection"):
		network.cancel_relay_connection()
		await process_frame
		check(not network.connection_in_progress, "cancel completes pending connection without duplicate player startup")
	else:
		network.authentication_deadline = Time.get_ticks_msec() - 1
		await process_frame
	for player in get_nodes_in_group("player"): player.queue_free()
	if network.peer != null and network.peer.connection != null:
		network.peer.connection.destroy()
		network.peer.connection = null
	if current_scene != null: current_scene.queue_free()
	if network.directory_browser != null: network.directory_browser.stop()
	if network.lan_discovery != null: network.lan_discovery.stop()
	await process_frame
	await process_frame
	print("\nReal startup acceptance: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)
