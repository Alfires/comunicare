extends SceneTree
var passed := 0
var failed := 0

class Appearance extends Node3D:
	var user_name := ""
	var requested: Array = []
	func load_player_model(url: String): requested.append(url)

func _initialize(): call_deferred("run")

func check(value: bool, title: String):
	if value: passed += 1; print("PASS: ", title)
	else: failed += 1; print("FAIL: ", title)

func coordinator():
	var node = load("res://scripts/multiplayer/network_handler.gd").new()
	node.peer = load("res://fixtures/recording_peer.gd").new()
	node.peer.current_session_id = "old"
	node.current_session_id = "old"
	node.peer.session_result.connect(node._on_session_result)
	root.add_child(node)
	return node

func run():
	test_profile_appearance()
	test_unmatched_result()
	await test_replacement_during_prepare()
	print("\nRED client reliability: %s passed, %s failed" % [passed, failed])
	quit(1 if failed else 0)

func test_profile_appearance():
	var node = coordinator()
	var actor = Appearance.new()
	actor.name = "7"
	node.add_child(actor)
	var label = Label3D.new()
	label.name = "user_name"
	actor.add_child(label)
	var key = Crypto.new().generate_rsa(2048)
	var service = load("res://scripts/profile/profile_service.gd").new()
	service.configure(key, "res://never-saved-remote.cfg")
	var fields: Dictionary = service.local.duplicate(true)
	fields["profile.username"] = "Remote Alice"
	fields["profile.avatar_url"] = "https://example.invalid/alice.vrm"
	service._sign(fields)
	fields.peer_id = 7
	node._on_profiles_updated("old", [fields])
	check(actor.user_name == "Remote Alice", "baseline verified profile updates remote display name")
	check(actor.requested == [fields["profile.avatar_url"]], "verified public profile applies its avatar URL to the matching remote actor")
	node._on_profiles_updated("old", [fields])
	check(actor.requested.size() == 1, "unchanged profile snapshot never duplicates appearance load")
	var before = actor.requested.size()
	node._on_profiles_updated("another-instance", [fields])
	check(actor.requested.size() == before, "another instance profile cannot load appearance")
	node.free()
	root.get_node("SaveData").profile.clear_remote_profiles()

func test_unmatched_result():
	var node = coordinator()
	node.pending_operation = "join"
	node.pending_id = "wanted"
	node.pending_deadline = Time.get_ticks_msec() + 60000
	node.peer.on_packet(SessionResult.create({"operation": "join", "session_id": "unrelated",
		"world_url": "default_wold", "success": true, "message": ""}).encode())
	check(node.current_session_id == "old", "coordinator ignores unrelated join acknowledgement")
	check(node.peer.current_session_id == "old", "transport must not commit an acknowledgement rejected by coordinator")
	check(node.pending_id == "wanted" and node.pending_operation == "join", "unrelated result does not finish current request")
	node.free()

func capture_join(node: Node, completed: Array):
	completed.append(await node.join_session("target", "default_wold"))

func test_replacement_during_prepare():
	var node = coordinator()
	var loader = root.get_node("DataLoader")
	loader.hold_prepare = true
	loader.activated = 0
	var old_peer = node.peer
	var completed: Array = []
	capture_join(node, completed)
	var replacement = load("res://fixtures/recording_peer.gd").new()
	replacement.current_session_id = "replacement-home"
	# Keep the legacy test from hanging: any wrongly issued join still reaches
	# the production coordinator, allowing the assertion to expose the mutation.
	replacement.session_result.connect(node._on_session_result)
	node.peer = replacement
	loader.prepared.emit()
	for i in 5: await process_frame
	check(replacement.joins.is_empty(), "staged join cannot migrate onto a replacement connection")
	check(completed == [false] and loader.activated == 0, "connection replacement cancels stale preparation before activation")
	check(old_peer.joins.is_empty(), "abandoned connection is not sent the old join either")
	loader.hold_prepare = false
	node.queue_free()
	await process_frame
